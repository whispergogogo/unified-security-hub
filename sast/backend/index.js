// One-shot ECS task: download zip from S3 → scan → upload report → update DynamoDB → exit
// Step Functions handles status → COMPLETED after this process exits 0.

import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import { DynamoDBClient, QueryCommand, UpdateItemCommand } from "@aws-sdk/client-dynamodb";
import { scanDirectory } from "./scanner.js";
import { createWriteStream, mkdirSync, rmSync } from "fs";
import { pipeline } from "stream/promises";
import { exec } from "child_process";
import { promisify } from "util";
import os from "os";
import path from "path";

const execAsync = promisify(exec);
const s3        = new S3Client({ region: "us-east-1" });
const dynamo    = new DynamoDBClient({ region: "us-east-1" });

// Injected by Step Functions ContainerOverrides (see sfn.tf)
const FINDING_ID     = process.env.FINDING_ID;
const S3_BUCKET      = process.env.S3_BUCKET;
const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE;

// Query DynamoDB by PK to get timestamp (SK) and s3UploadKey
const getJob = async () => {
  const res = await dynamo.send(new QueryCommand({
    TableName: DYNAMODB_TABLE,
    KeyConditionExpression: "finding_id = :id",
    ExpressionAttributeValues: { ":id": { S: FINDING_ID } },
    Limit: 1,
  }));
  if (!res.Items?.length) throw new Error(`Job not found: ${FINDING_ID}`);
  return res.Items[0];
};

// Stream S3 object to local file
const downloadFromS3 = async (key, destPath) => {
  const res = await s3.send(new GetObjectCommand({ Bucket: S3_BUCKET, Key: key }));
  await pipeline(res.Body, createWriteStream(destPath));
};

// Upload JSON report to S3
const uploadReport = async (key, report) => {
  await s3.send(new PutObjectCommand({
    Bucket: S3_BUCKET,
    Key: key,
    Body: JSON.stringify(report, null, 2),
    ContentType: "application/json",
  }));
};

// Write s3ReportKey + severity back to DynamoDB
// timestamp is the Sort Key — required for UpdateItem
const updateJobResult = async (timestamp, s3ReportKey, severity) => {
  await dynamo.send(new UpdateItemCommand({
    TableName: DYNAMODB_TABLE,
    Key: {
      finding_id: { S: FINDING_ID },
      timestamp:  { S: timestamp },
    },
    UpdateExpression: "SET s3ReportKey = :r, severity = :sev",
    ExpressionAttributeValues: {
      ":r":   { S: s3ReportKey },
      ":sev": { S: severity },
    },
  }));
};

// Pick worst severity from findings list
const topSeverity = (vulns) => {
  for (const sev of ["HIGH", "MEDIUM", "LOW"]) {
    if (vulns.some(v => v.severity === sev)) return sev;
  }
  return "INFO";
};

const main = async () => {
  console.log(`[SAST] findingId=${FINDING_ID} bucket=${S3_BUCKET} table=${DYNAMODB_TABLE}`);

  if (!FINDING_ID || !S3_BUCKET || !DYNAMODB_TABLE) {
    throw new Error("Missing env vars: FINDING_ID, S3_BUCKET, DYNAMODB_TABLE");
  }

  // 1. Fetch job — need timestamp (SK) and s3UploadKey
  const job         = await getJob();
  const timestamp   = job.timestamp?.S;
  const s3UploadKey = job.s3UploadKey?.S;
  if (!s3UploadKey) throw new Error("s3UploadKey not set — zip was not uploaded yet");

  // 2. Set up temp workspace
  const tmpDir  = path.join(os.tmpdir(), `sast-${FINDING_ID}`);
  const zipPath = path.join(tmpDir, "source.zip");
  const srcDir  = path.join(tmpDir, "source");
  mkdirSync(srcDir, { recursive: true });

  try {
    // 3. Download zip from S3
    console.log(`[SAST] Downloading s3://${S3_BUCKET}/${s3UploadKey}`);
    await downloadFromS3(s3UploadKey, zipPath);

    // 4. Unzip
    await execAsync(`unzip -q "${zipPath}" -d "${srcDir}"`);

    // 5. Scan using teacher-provided scanner.js
    console.log(`[SAST] Scanning ${srcDir}`);
    const resultsByFile = scanDirectory(srcDir);
    const allVulns      = Object.values(resultsByFile).flat();
    const severity      = topSeverity(allVulns);

    // 6. Build report
    const report = {
      findingId: FINDING_ID,
      scanType:  "SAST",
      scannedAt: new Date().toISOString(),
      severity,
      summary: {
        total:  allVulns.length,
        high:   allVulns.filter(v => v.severity === "HIGH").length,
        medium: allVulns.filter(v => v.severity === "MEDIUM").length,
        low:    allVulns.filter(v => v.severity === "LOW").length,
        info:   allVulns.filter(v => v.severity === "INFO").length,
      },
      results: resultsByFile,
    };

    // 7. Upload report to S3
    const reportKey = `reports/${FINDING_ID}/report.json`;
    console.log(`[SAST] Uploading report → s3://${S3_BUCKET}/${reportKey}`);
    await uploadReport(reportKey, report);

    // 8. Write reportKey + severity to DynamoDB
    // Step Functions will set status → COMPLETED after container exits 0
    console.log(`[SAST] Updating DynamoDB severity=${severity}`);
    await updateJobResult(timestamp, reportKey, severity);

    console.log(`[SAST] Done. ${allVulns.length} finding(s), severity=${severity}`);
    process.exit(0);

  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }
};

main().catch(err => {
  console.error("[SAST] Fatal:", err.message);
  process.exit(1);
});