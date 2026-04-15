export default function MetaItem({ label, value }) {
  return (
    <div>
      <p className="text-xs text-gray-400">{label}</p>
      <p className="text-xs text-gray-700 font-medium mt-0.5 break-all">{value}</p>
    </div>
  )
}