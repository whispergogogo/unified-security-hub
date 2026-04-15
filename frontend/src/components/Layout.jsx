import { Outlet, NavLink, useLocation } from 'react-router-dom'
import { ShieldCheck, LayoutDashboard, ScanLine } from 'lucide-react'

const navItems = [
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/scan/new',  label: 'New Scan',  icon: ScanLine },
]

export default function Layout() {
  return (
    <div className="flex h-screen bg-gray-50">

      {/* Sidebar */}
      <aside className="w-56 bg-white border-r border-gray-200 flex flex-col">
        {/* Logo */}
        <div className="flex items-center gap-2.5 px-5 py-5 border-b border-gray-200">
          <ShieldCheck className="text-blue-600" size={22} />
          <span className="font-semibold text-gray-800 text-sm leading-tight">
            Unified<br />Security Hub
          </span>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 space-y-1">
          {navItems.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-blue-50 text-blue-700'
                    : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
                }`
              }
            >
              <Icon size={16} />
              {label}
            </NavLink>
          ))}
        </nav>

        {/* Footer */}
          <div className="px-5 py-4 border-t border-gray-200 space-y-1">
          <p className="text-xs text-gray-400">CS6620 Cloud Computing</p>
          <p className="text-xs text-gray-400">Group 3</p>
          <p className="text-xs text-gray-400">Aarushi Kaushik</p>
          <p className="text-xs text-gray-400">Junrui Ding</p>
          <p className="text-xs text-gray-400">Ran Zhao</p>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Top bar */}
        <header className="h-14 bg-white border-b border-gray-200 flex items-center px-6">
          <PageTitle />
        </header>

        {/* Page content */}
        <main className="flex-1 overflow-y-auto p-6">
          <Outlet />
        </main>
      </div>
    </div>
  )
}

function PageTitle() {
  const { pathname } = useLocation()
  const titles = {
    '/dashboard': 'Dashboard',
    '/scan/new':  'New Scan',
  }
  const title = Object.entries(titles).find(([k]) => pathname.startsWith(k))?.[1]
    ?? 'Scan Report'
  return <h1 className="text-base font-semibold text-gray-800">{title}</h1>
}