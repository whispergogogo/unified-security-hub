const styles = {
  COMPLETED: 'bg-green-100 text-green-700 border-green-200',
  RUNNING:   'bg-blue-100 text-blue-700 border-blue-200',
  PENDING:   'bg-yellow-100 text-yellow-700 border-yellow-200',
  FAILED:    'bg-red-100 text-red-700 border-red-200',
}

const labels = {
  COMPLETED: 'Completed',
  RUNNING:   'Running',
  PENDING:   'Pending',
  FAILED:    'Failed',
}

export default function StatusBadge({ status }) {
  const cls = styles[status] ?? 'bg-gray-100 text-gray-700 border-gray-200'
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border ${cls}`}>
      {status === 'RUNNING' && (
        <span className="mr-1.5 h-1.5 w-1.5 rounded-full bg-blue-500 animate-pulse" />
      )}
      {labels[status] ?? status}
    </span>
  )
}