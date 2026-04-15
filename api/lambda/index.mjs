import { DynamoDBClient, PutItemCommand, GetItemCommand, UpdateItemCommand, QueryCommand } from "@aws-sdk/client-dynamodb";
import { S3Client, PutObjectCommand, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { SFNClient, StartExecutionCommand } from "@aws-sdk/client-sfn";
import { randomUUID } from "crypto";

const dynamo = new DynamoDBClient({});
const s3     = new S3Client({});
const sfn    = new SFNClient({});

const TABLE  = process.env.DYNAMODB_TABLE;  // unified-security-hub-findings-dev
const BUCKET = process.env.S3_BUCKET;
const SFN_ARN = process.env.SFN_ARN;

export const handler = async (event) => {
  // Handle CORS preflight — no API key required
  if (event.httpMethod === "OPTIONS") {
    return res(200, {});
  }
  const method  = event.httpMethod;
  const path    = event.resource;
  const findingId = event.pathParameters?.findingId;

  try {

    // ── POST /scan-jobs ── create a new scan job ──────────────────────────
    if (method === "POST" && path === "/scan-jobs") {
      const body = JSON.parse(event.body || "{}");
      // destructure request body; userId defaults to "default-user" if not provided
      const { scanType, targetUrl, userId = "default-user" } = body;

      if (!scanType || !["SAST", "PENTEST"].includes(scanType)) {
        return res(400, { error: "scanType must be SAST or PENTEST" });
      }
      if (scanType === "PENTEST" && !targetUrl) {
        return res(400, { error: "targetUrl required for PENTEST" });
      }

      const id           = randomUUID();
      const now          = new Date().toISOString();
      // SAST jobs need a file upload path; PENTEST jobs don't (no file, just a URL to test)
      const s3UploadKey  = scanType === "SAST" ? `uploads/${id}/source.zip` : null;

      await dynamo.send(new PutItemCommand({
        TableName: TABLE,
        Item: {
          finding_id:  { S: id },
          timestamp:   { S: now },          // SK
          source:      { S: scanType },     // GSI: SourceIndex
          status:      { S: "PENDING" },    // GSI: StatusIndex
          severity:    { S: "INFO" },       // GSI: SeverityIndex — updated after scan
          userId:      { S: userId },
          // conditional spread: only add the field if the value exists
          // DynamoDB rejects null values, so omit the field entirely when not applicable
          ...(s3UploadKey && { s3UploadKey: { S: s3UploadKey } }),
          ...(targetUrl   && { targetUrl:   { S: targetUrl } }),
        }
      }));

      // Generate pre-signed S3 upload URL for SAST
      let uploadUrl = null;
      if (scanType === "SAST") {
        uploadUrl = await getSignedUrl(s3, new PutObjectCommand({
          Bucket: BUCKET,
          Key: s3UploadKey,
        }), { expiresIn: 900 });
      }

      return res(201, { findingId: id, status: "PENDING", uploadUrl });
    }

    // ── GET /scan-jobs ── list all jobs (query by source via GSI) ─────────
    if (method === "GET" && path === "/scan-jobs") {
      const source = event.queryStringParameters?.source; // optional filter

      let result;
      if (source) {
        // Use SourceIndex GSI to filter by SAST or PENTEST
        result = await dynamo.send(new QueryCommand({
          TableName: TABLE,
          IndexName: "SourceIndex",
          KeyConditionExpression: "#src = :s",
          ExpressionAttributeNames: { "#src": "source" },
          ExpressionAttributeValues: { ":s": { S: source } },
          ScanIndexForward: false, // newest first
        }));
      } else {
        // Query StatusIndex to get all jobs regardless of status
        const statuses = ["PENDING", "RUNNING", "COMPLETED", "FAILED"];
        const allItems = [];
        for (const st of statuses) {
          const r = await dynamo.send(new QueryCommand({
            TableName: TABLE,
            IndexName: "StatusIndex",
            KeyConditionExpression: "#s = :s",
            ExpressionAttributeNames: { "#s": "status" },
            ExpressionAttributeValues: { ":s": { S: st } },
          }));
          // ...(array) spreads array elements as individual push arguments
          // r.Items || [] guards against undefined if the query returns no results
          allItems.push(...(r.Items || []));
        }
        // formatItem strips DynamoDB type tags: { S: "PENDING" } → "PENDING"
        return res(200, { jobs: allItems.map(formatItem) });
      }

      return res(200, { jobs: (result.Items || []).map(formatItem) });
    }

    // ── GET /scan-jobs/{findingId} ── get single job ──────────────────────
    if (method === "GET" && path === "/scan-jobs/{findingId}") {
      // GetItem requires both PK and SK; we only have PK here, so use Query instead
      // finding_id is not a reserved word — no #alias needed, unlike "source" or "status"
      const result = await dynamo.send(new QueryCommand({
        TableName: TABLE,
        KeyConditionExpression: "finding_id = :id",
        ExpressionAttributeValues: { ":id": { S: findingId } },
        Limit: 1,  // each findingId has exactly one record — stop after the first match
      }));

      if (!result.Items || result.Items.length === 0) {
        return res(404, { error: "Job not found" });
      }

      // result.Items is always an array even for a single record — take index [0]
      return res(200, formatItem(result.Items[0]));
    }

    // ── POST /scan-jobs/{findingId}/start ── trigger the scan ─────────────
    if (method === "POST" && path === "/scan-jobs/{findingId}/start") {
      const result = await dynamo.send(new QueryCommand({
        TableName: TABLE,
        KeyConditionExpression: "finding_id = :id",
        ExpressionAttributeValues: { ":id": { S: findingId } },
        Limit: 1,
      }));

      if (!result.Items || result.Items.length === 0) {
        return res(404, { error: "Job not found" });
      }

      const item     = result.Items[0];
      const source   = item.source?.S;   // "SAST" or "PENTEST"
      const status   = item.status?.S;   // must be "PENDING" to proceed
      const ts       = item.timestamp?.S; // needed as SK for the UpdateItem below

      if (status !== "PENDING") {
        return res(400, { error: `Job is already ${status}` });
      }
      // SAST jobs require a zip to be uploaded before starting
      // !item.s3UploadKey?.S : ?. safely accesses .S (returns undefined if field missing), ! checks if falsy
      if (source === "SAST" && !item.s3UploadKey?.S) {
        return res(400, { error: "Upload the source zip first" });
      }

      // Start Step Functions FIRST — only update DB if it succeeds
      // Reversed order prevents status getting stuck as RUNNING if SFN fails to start
      try {
        await sfn.send(new StartExecutionCommand({
          stateMachineArn: SFN_ARN,
          name:  `scan-${findingId}`,
          input: JSON.stringify({
            findingId,
            scanType:    source,
            s3UploadKey: item.s3UploadKey?.S ?? null,
            targetUrl:   item.targetUrl?.S   ?? null,
            s3Bucket:    BUCKET,
            timestamp:   ts,
          }),
        }));
      } catch (sfnErr) {
        // SFN failed — update status to FAILED so the user knows, then surface the error
        await dynamo.send(new UpdateItemCommand({
          TableName: TABLE,
          Key: { finding_id: { S: findingId }, timestamp: { S: ts } },
          UpdateExpression: "SET #s = :s, errorMessage = :e",
          ExpressionAttributeNames:  { "#s": "status" },
          ExpressionAttributeValues: {
            ":s": { S: "FAILED" },
            ":e": { S: sfnErr.message },
          },
        }));
        return res(500, { error: "Failed to start scan", detail: sfnErr.message });
      }

      // SFN started successfully — now safe to mark as RUNNING
      await dynamo.send(new UpdateItemCommand({
        TableName: TABLE,
        Key: {
          finding_id: { S: findingId },
          timestamp:  { S: ts },
        },
        UpdateExpression: "SET #s = :s",
        ExpressionAttributeNames:  { "#s": "status" },
        ExpressionAttributeValues: { ":s": { S: "RUNNING" } },
      }));

      return res(200, { findingId, status: "RUNNING" });
    }

    // ── GET /scan-jobs/{findingId}/report ── fetch report JSON from S3 ────────
    if (method === "GET" && path === "/scan-jobs/{findingId}/report") {
      const result = await dynamo.send(new QueryCommand({
        TableName: TABLE,
        KeyConditionExpression: "finding_id = :id",
        ExpressionAttributeValues: { ":id": { S: findingId } },
        Limit: 1,
      }));

      // !result.Items?.length : ?. guards against null Items, ! checks length is 0 or falsy
      // operator precedence: ?. runs first, then !
      if (!result.Items?.length) return res(404, { error: "Job not found" });

      // s3ReportKey is written by the scanner after it finishes — null means scan not done yet
      const s3ReportKey = result.Items[0].s3ReportKey?.S;
      if (!s3ReportKey) return res(404, { error: "Report not ready yet" });

      // fetch the report file from S3 and stream it back to the frontend
      // S3 Body is a stream (not a string) — transformToString() collects it all into a string
      const s3Res = await s3.send(new GetObjectCommand({
        Bucket: BUCKET,
        Key: s3ReportKey,
      }));
      const reportJson = await s3Res.Body.transformToString();
      return {
        statusCode: 200,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
        body: reportJson,
      };
    }

    return res(404, { error: "Route not found" });

  } catch (err) {
    console.error(err);
    return res(500, { error: err.message });
  }
};

// ── helpers ───────────────────────────────────────────────────────────────
const formatItem = (item) => ({
  findingId:   item.finding_id?.S,
  timestamp:   item.timestamp?.S,
  source:      item.source?.S,
  status:      item.status?.S,
  severity:    item.severity?.S,
  userId:      item.userId?.S,
  s3ReportKey: item.s3ReportKey?.S,
  targetUrl:   item.targetUrl?.S,
  errorMessage:item.errorMessage?.S,
});

const CORS_HEADERS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "Content-Type,x-api-key",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
};

const res = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  body: JSON.stringify(body),
});
