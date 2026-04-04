const styles = {
  HIGH:     'bg-red-100 text-red-700 border-red-200',
  MEDIUM:   'bg-orange-100 text-orange-700 border-orange-200',
  LOW:      'bg-yellow-100 text-yellow-700 border-yellow-200',
  INFO:     'bg-gray-100 text-gray-600 border-gray-200',
  CRITICAL: 'bg-red-200 text-red-800 border-red-300',
}

export default function SeverityBadge({ severity }) {
  const cls = styles[severity] ?? styles.INFO
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border ${cls}`}>
      {severity ?? 'INFO'}
    </span>
  )
}