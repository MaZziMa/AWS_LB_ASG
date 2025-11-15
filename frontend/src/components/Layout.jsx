import { Outlet, Link, useNavigate, useLocation } from 'react-router-dom'
import { useAuthStore } from '../store/authStore'
import './Layout.css'

function Layout() {
  const { user, logout } = useAuthStore()
  const navigate = useNavigate()
  const location = useLocation()

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  const isActive = (path) => location.pathname === path ? 'active' : ''

  return (
    <div className="layout">
      <nav className="navbar">
        <div className="navbar-brand">
          <h1>🎓 Course Registration</h1>
        </div>
        
        <div className="navbar-menu">
          <Link to="/dashboard" className={`nav-link ${isActive('/dashboard')}`}>
            Dashboard
          </Link>
          <Link to="/courses" className={`nav-link ${isActive('/courses')}`}>
            All Courses
          </Link>
          <Link to="/my-courses" className={`nav-link ${isActive('/my-courses')}`}>
            My Courses
          </Link>
          {user?.user_type === 'admin' && (
            <Link to="/admin" className={`nav-link ${isActive('/admin')}`}>
              Admin Panel
            </Link>
          )}
        </div>
        
        <div className="navbar-user">
          <span className="user-info">
            👤 {user?.full_name} ({user?.user_type})
          </span>
          <button onClick={handleLogout} className="btn-logout">
            Logout
          </button>
        </div>
      </nav>
      
      <main className="main-content">
        <Outlet />
      </main>
    </div>
  )
}

export default Layout
