
export default function SummaryPill({ label, count, color }) {
  const colors = {
    red:    'bg-red-100 text-red-700',
    orange: 'bg-orange-100 text-orange-700',
    yellow: 'bg-yellow-100 text-yellow-700',
    green:  'bg-green-100 text-green-700',
    gray:   'bg-gray-100 text-gray-600',
  }
  if (!count) return null
  return (
    <span className={`text-xs font-medium px-2.5 py-1 rounded-full ${colors[color]}`}>
      {count} {label}
    </span>
  )
}