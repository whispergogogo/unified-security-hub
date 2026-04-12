import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { ArrowLeft, ChevronDown, ChevronRight, FileCode, Download } from 'lucide-react'
import { getJob, getReport } from '../api/client'
import MetaItem from '../components/MetaItem'
import SeverityBadge from '../components/SeverityBadge'
import SeverityChart from '../components/SeverityChart'
import StatusBadge from '../components/StatusBadge'
import SummaryPill from '../components/SummaryPill'

const SEVERITY_ORDER = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO']

export default function ReportDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [job, setJob]       = useState(null)
  const [report, setReport] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const load = async () => {
      try {
        const [j, r] = await Promise.all([getJob(id), getReport(id)])
        setJob(j)
        setReport(r)
      } catch (e) {
        console.error(e)
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [id])

  if (loading) return <div className="text-sm text-gray-400 py-12 text-center">Loading report...</div>
  if (!report)  return <div className="text-sm text-gray-400 py-12 text-center">Report not available.</div>

  // Flatten all findings from all files
  const allFindings = report.scanType === 'SAST'
    ? Object.values(report.results ?? {}).flat()
    : (report.results ?? [])

  // Group by severity (SAST only)
  const grouped = SEVERITY_ORDER.reduce((acc, sev) => {
    const items = allFindings.filter(f => f.severity === sev)
    if (items.length) acc[sev] = items
    return acc
  }, {})

  // Severity chart data — works for both SAST and Pentest
  const severityCounts = (() => {
    if (report.scanType === 'SAST') {
      return [
        { label: 'Critical', count: report.summary?.critical ?? 0, color: '#991b1b', bg: '#fecaca' },
        { label: 'High',     count: report.summary?.high     ?? 0, color: '#dc2626', bg: '#fca5a5' },
        { label: 'Medium',   count: report.summary?.medium   ?? 0, color: '#ea580c', bg: '#fed7aa' },
        { label: 'Low',      count: report.summary?.low      ?? 0, color: '#ca8a04', bg: '#fef08a' },
        { label: 'Info',     count: report.summary?.info     ?? 0, color: '#6b7280', bg: '#e5e7eb' },
      ]
    }
    // Pentest: count failed tests by their severity field
    const results = report.results ?? []
    const failedBySev = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 }
    for (const r of results) {
      if (r.status === 'FAIL' || r.status === 'WARNING') {
        const sev = (r.severity ?? 'INFO').toUpperCase()
        if (sev in failedBySev) failedBySev[sev]++
      }
    }
    return [
      { label: 'Critical', count: failedBySev.CRITICAL, color: '#991b1b', bg: '#fecaca' },
      { label: 'High',     count: failedBySev.HIGH,     color: '#dc2626', bg: '#fca5a5' },
      { label: 'Medium',   count: failedBySev.MEDIUM,   color: '#ea580c', bg: '#fed7aa' },
      { label: 'Low',      count: failedBySev.LOW,      color: '#ca8a04', bg: '#fef08a' },
      { label: 'Info',     count: failedBySev.INFO,     color: '#6b7280', bg: '#e5e7eb' },
    ]
  })()

  const hasAnySeverity = severityCounts.some(s => s.count > 0)
  const maxCount = Math.max(...severityCounts.map(s => s.count), 1)

  return (
    <div className="max-w-3xl space-y-5">

      {/* Back */}
      <button
        onClick={() => navigate('/dashboard')}
        className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 transition-colors"
      >
        <ArrowLeft size={14} />
        Back to Dashboard
      </button>

      {/* Job metadata */}
      <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-5">
        <div className="flex items-start justify-between mb-4">
          <div>
            <h2 className="text-sm font-semibold text-gray-800 mb-1">
              {report.scanType} Scan Report
            </h2>
            <p className="font-mono text-xs text-gray-400">{id}</p>
          </div>
          <div className="flex gap-2">
            {job && <StatusBadge status={job.status} />}
            <SeverityBadge severity={report.severity} />
          </div>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 text-xs text-gray-600">
          <MetaItem label="Scan type"  value={report.scanType} />
          <MetaItem label="Scanned at" value={new Date(report.scannedAt).toLocaleString()} />
          {report.targetUrl && <MetaItem label="Target" value={report.targetUrl} />}
          {job?.userId && <MetaItem label="User" value={job.userId} />}
        </div>
      </div>

      {/* Severity summary chart (SAST) or Pentest summary pills */}
      <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-5">
        <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">
          Summary — {report.summary?.total ?? allFindings.length} {report.scanType === 'SAST' ? 'findings' : 'tests'}
        </h3>

        {report.scanType === 'SAST' ? (
          <div className="space-y-4">
            <div className="flex gap-3 flex-wrap">
              <SummaryPill label="Critical" count={report.summary?.critical} color="red" />
              <SummaryPill label="High"     count={report.summary?.high}     color="red" />
              <SummaryPill label="Medium"   count={report.summary?.medium}   color="orange" />
              <SummaryPill label="Low"      count={report.summary?.low}      color="yellow" />
              <SummaryPill label="Info"     count={report.summary?.info}     color="gray" />
            </div>
            <SeverityChart data={severityCounts} maxCount={maxCount} />
          </div>
        ) : (
          <div className="space-y-4">
            <div className="flex gap-3 flex-wrap">
              <SummaryPill label="Failed"  count={report.summary?.failed}  color="red" />
              <SummaryPill label="Warning" count={report.summary?.warned}  color="orange" />
              <SummaryPill label="Passed"  count={report.summary?.passed}  color="green" />
              <SummaryPill label="Errored" count={report.summary?.errored} color="gray" />
            </div>
            {hasAnySeverity && (
              <>
                <p className="text-xs text-gray-400 uppercase tracking-wide font-semibold pt-2">Failed by severity</p>
                <SeverityChart data={severityCounts} maxCount={maxCount} />
              </>
            )}
          </div>
        )}
      </div>

      {/* Findings grouped by severity */}
      {report.scanType === 'SAST' ? (
        <div className="space-y-4">
          {Object.entries(grouped).map(([sev, findings]) => (
            <FindingsGroup key={sev} severity={sev} findings={findings} />
          ))}
        </div>
      ) : (
        <PentestResults results={report.results} />
      )}

      {/* Download link */}
      {job?.s3ReportKey && (
        <div className="text-right">
          <button
            onClick={async () => {
              const data = await getReport(id)
              if (!data) return
              const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
              const url = URL.createObjectURL(blob)
              const a = document.createElement('a')
              a.href = url
              a.download = `report-${id}.json`
              a.click()
              URL.revokeObjectURL(url)
            }}
            className="inline-flex items-center gap-1.5 text-xs text-blue-600 hover:underline"
          >
            <Download size={13} />
            Download raw JSON
          </button>
        </div>
      )}
    </div>
  )
}

// ── SAST findings group ───────────────────────────────────────────────────────
function FindingsGroup({ severity, findings }) {
  const [open, setOpen] = useState(severity === 'CRITICAL' || severity === 'HIGH')

  return (
    <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
      <button
        onClick={() => setOpen(o => !o)}
        className="w-full flex items-center justify-between px-5 py-3 hover:bg-gray-50 transition-colors"
      >
        <div className="flex items-center gap-2">
          <SeverityBadge severity={severity} />
          <span className="text-xs text-gray-500">{findings.length} finding{findings.length > 1 ? 's' : ''}</span>
        </div>
        {open ? <ChevronDown size={15} className="text-gray-400" /> : <ChevronRight size={15} className="text-gray-400" />}
      </button>

      {open && (
        <div className="divide-y divide-gray-50">
          {findings.map((f, i) => (
            <FindingRow key={i} finding={f} />
          ))}
        </div>
      )}
    </div>
  )
}

function FindingRow({ finding }) {
  const [expanded, setExpanded] = useState(false)
  const filename = (finding.file ?? '').split('/').pop() || 'unknown'

  return (
    <div className="px-5 py-3">
      <div
        className="flex items-start justify-between cursor-pointer"
        onClick={() => setExpanded(e => !e)}
      >
        <div>
          <p className="text-sm font-medium text-gray-800">{finding.name}</p>
          <p className="text-xs text-gray-500 mt-0.5">{finding.description}</p>
        </div>
        <div className="flex items-center gap-3 ml-4 flex-shrink-0">
          {finding.line && (
            <div className="flex items-center gap-1 text-xs text-gray-400">
              <FileCode size={12} />
              {filename}:{finding.line}
            </div>
          )}
          {expanded
            ? <ChevronDown size={13} className="text-gray-400" />
            : <ChevronRight size={13} className="text-gray-400" />
          }
        </div>
      </div>

      {expanded && (
        <div className="mt-3 space-y-2">
          {finding.evidence && (
            <pre className="bg-gray-900 text-green-400 text-xs rounded-lg px-4 py-3 overflow-x-auto">
              {finding.evidence}
            </pre>
          )}
          {finding.message && (
            <p className="text-xs text-gray-600 bg-blue-50 px-3 py-2 rounded-lg">
              💡 {finding.message}
            </p>
          )}
        </div>
      )}
    </div>
  )
}

// ── Pentest results ───────────────────────────────────────────────────────────
function PentestResults({ results }) {
  if (!Array.isArray(results)) return null

  const statusColor = {
    PASS:    'text-green-700 bg-green-50 border-green-200',
    FAIL:    'text-red-700 bg-red-50 border-red-200',
    WARNING: 'text-orange-700 bg-orange-50 border-orange-200',
    ERROR:   'text-gray-700 bg-gray-50 border-gray-200',
  }

  return (
    <div className="space-y-3">
      {results.map(r => (
        <PentestCard key={r.id} result={r} statusColor={statusColor} />
      ))}
    </div>
  )
}

function PentestCard({ result: r, statusColor }) {
  const [expanded, setExpanded] = useState(r.status === 'FAIL')

  return (
    <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
      <div
        className="flex items-center justify-between px-5 py-3 cursor-pointer hover:bg-gray-50 transition-colors"
        onClick={() => setExpanded(e => !e)}
      >
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium text-gray-800">{r.name}</p>
          <p className="text-xs text-gray-500 mt-0.5 truncate">{r.details}</p>
        </div>
        <div className="flex items-center gap-2 ml-4 flex-shrink-0">
          <span className={`text-xs font-medium px-2.5 py-0.5 rounded-full border ${statusColor[r.status] ?? statusColor.ERROR}`}>
            {r.status}
          </span>
          {expanded
            ? <ChevronDown size={13} className="text-gray-400" />
            : <ChevronRight size={13} className="text-gray-400" />
          }
        </div>
      </div>

      {expanded && r.findings?.length > 0 && (
        <div className="px-5 pb-4">
          <ul className="space-y-1">
            {r.findings.map((f, i) => (
              <li key={i} className="text-xs text-gray-600 bg-gray-50 px-3 py-1.5 rounded-lg">
                {f.issue}
                {f.evidence && <span className="text-gray-400"> — {f.evidence}</span>}
                {f.recommendation && (
                  <p className="text-blue-600 mt-0.5">💡 {f.recommendation}</p>
                )}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}
