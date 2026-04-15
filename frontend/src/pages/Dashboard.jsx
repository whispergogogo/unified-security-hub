import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { listJobs } from '../api/client'
import StatusBadge from '../components/StatusBadge'
import SeverityBadge from '../components/SeverityBadge'
import { RefreshCw, Plus, ChevronRight } from 'lucide-react'

const POLL_INTERVAL = 10000 // 10 seconds

export default function Dashboard() {
  const [jobs, setJobs]         = useState([])
  const [loading, setLoading]   = useState(true)
  const [lastRefresh, setLastRefresh] = useState(null)
  const navigate = useNavigate()

  const fetchJobs = async () => {
    try {
      const data = await listJobs()
      // Sort newest first
      const sorted = (data.jobs ?? []).sort(
        (a, b) => new Date(b.timestamp) - new Date(a.timestamp)
      )
      setJobs(sorted)
      setLastRefresh(new Date())
    } catch (e) {
      console.error('Failed to fetch jobs:', e)
    } finally {
      setLoading(false)
    }
  }

  // Initial load + polling every 10s
  useEffect(() => {
    fetchJobs()
    const timer = setInterval(fetchJobs, POLL_INTERVAL)
    return () => clearInterval(timer)
  }, [])

  // Summary counts
  const total     = jobs.length
  const running   = jobs.filter(j => j.status === 'RUNNING').length
  const completed = jobs.filter(j => j.status === 'COMPLETED').length
  const failed    = jobs.filter(j => j.status === 'FAILED').length

  return (
    <div className="space-y-6">

      {/* Summary cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <SummaryCard label="Total Scans"  value={total}     color="blue" />
        <SummaryCard label="Completed"    value={completed} color="green" />
        <SummaryCard label="Running"      value={running}   color="indigo" />
        <SummaryCard label="Failed"       value={failed}    color="red" />
      </div>

      {/* Job list */}
      <div className="bg-white rounded-xl border border-gray-200 shadow-sm">
        {/* Table header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100">
          <h2 className="text-sm font-semibold text-gray-700">Scan Jobs</h2>
          <div className="flex items-center gap-3">
            {lastRefresh && (
              <span className="text-xs text-gray-400">
                Updated {lastRefresh.toLocaleTimeString()}
              </span>
            )}
            <button
              onClick={fetchJobs}
              className="flex items-center gap-1.5 text-xs text-gray-500 hover:text-gray-700 transition-colors"
            >
              <RefreshCw size={13} />
              Refresh
            </button>
            <button
              onClick={() => navigate('/scan/new')}
              className="flex items-center gap-1.5 text-xs bg-blue-600 text-white px-3 py-1.5 rounded-lg hover:bg-blue-700 transition-colors"
            >
              <Plus size={13} />
              New Scan
            </button>
          </div>
        </div>

        {/* Table */}
        {loading ? (
          <div className="py-16 text-center text-sm text-gray-400">Loading...</div>
        ) : jobs.length === 0 ? (
          <div className="py-16 text-center text-sm text-gray-400">
            No scans yet.{' '}
            <button onClick={() => navigate('/scan/new')} className="text-blue-600 hover:underline">
              Start your first scan
            </button>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="text-xs text-gray-500 border-b border-gray-100">
                <th className="text-left px-5 py-3 font-medium">Job ID</th>
                <th className="text-left px-5 py-3 font-medium">Type</th>
                <th className="text-left px-5 py-3 font-medium">Status</th>
                <th className="text-left px-5 py-3 font-medium">Severity</th>
                <th className="text-left px-5 py-3 font-medium">Created</th>
                <th className="px-5 py-3" />
              </tr>
            </thead>
            <tbody>
              {jobs.map(job => (
                <tr
                  key={job.findingId}
                  onClick={() => job.status === 'COMPLETED' && navigate(`/scan/${job.findingId}`)}
                  className={`border-b border-gray-50 last:border-0 transition-colors ${
                    job.status === 'COMPLETED' ? 'hover:bg-gray-50 cursor-pointer' : ''
                  }`}
                >
                  <td className="px-5 py-3 font-mono text-xs text-gray-500">
                    {job.findingId.slice(0, 8)}...
                  </td>
                  <td className="px-5 py-3">
                    <span className={`text-xs font-medium px-2 py-0.5 rounded ${
                      job.source === 'SAST'
                        ? 'bg-purple-100 text-purple-700'
                        : 'bg-teal-100 text-teal-700'
                    }`}>
                      {job.source}
                    </span>
                  </td>
                  <td className="px-5 py-3">
                    <StatusBadge status={job.status} />
                  </td>
                  <td className="px-5 py-3">
                    {job.severity && job.severity !== 'INFO'
                      ? <SeverityBadge severity={job.severity} />
                      : <span className="text-xs text-gray-400">—</span>
                    }
                  </td>
                  <td className="px-5 py-3 text-xs text-gray-500">
                    {new Date(job.timestamp).toLocaleString()}
                  </td>
                  <td className="px-5 py-3 text-gray-400">
                    {job.status === 'COMPLETED' && <ChevronRight size={15} />}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}

function SummaryCard({ label, value, color }) {
  const colors = {
    blue:   'text-blue-600 bg-blue-50',
    green:  'text-green-600 bg-green-50',
    indigo: 'text-indigo-600 bg-indigo-50',
    red:    'text-red-600 bg-red-50',
  }
  return (
    <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-4">
      <p className="text-xs text-gray-500 mb-1">{label}</p>
      <p className={`text-2xl font-bold ${colors[color].split(' ')[0]}`}>{value}</p>
    </div>
  )
}