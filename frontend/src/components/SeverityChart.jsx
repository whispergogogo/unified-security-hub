export default function SeverityChart({ data, maxCount }) {
  return (
    <div className="space-y-2">
      {data.map(({ label, count, color, bg }) => (
        <div key={label} className="flex items-center gap-3">
          <span className="text-xs text-gray-500 w-14 text-right">{label}</span>
          <div className="flex-1 bg-gray-100 rounded-full h-5 overflow-hidden">
            {count > 0 && (
              <div
                className="h-full rounded-full flex items-center justify-end pr-2 transition-all duration-500"
                style={{
                  width: `${Math.max((count / maxCount) * 100, 8)}%`,
                  backgroundColor: bg,
                  border: `1px solid ${color}40`,
                }}
              >
                <span className="text-xs font-semibold" style={{ color }}>{count}</span>
              </div>
            )}
          </div>
        </div>
      ))}
    </div>
  )
}