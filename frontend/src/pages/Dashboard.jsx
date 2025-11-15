import { useEffect, useState } from 'react'
import { useAuthStore } from '../store/authStore'
import { coursesAPI } from '../api/courses'
import { enrollmentsAPI } from '../api/enrollments'
import './Dashboard.css'

function Dashboard() {
  const { user } = useAuthStore()
  const [stats, setStats] = useState({
    totalCourses: 0,
    myCourses: 0,
    totalCredits: 0
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadDashboardData()
  }, [])

  const loadDashboardData = async () => {
    try {
      const [courses, enrollments] = await Promise.all([
        coursesAPI.getAllCourses(),
        user.user_type === 'student' ? enrollmentsAPI.getMyEnrollments() : Promise.resolve([])
      ])

      const totalCredits = enrollments.reduce((sum, e) => sum + (e.course?.credits || 0), 0)

      setStats({
        totalCourses: courses.length,
        myCourses: enrollments.length,
        totalCredits
      })
    } catch (error) {
      console.error('Failed to load dashboard data:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return <div className="loading">Loading dashboard...</div>
  }

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <h1>Welcome, {user?.full_name}! 👋</h1>
        <p className="user-role">Role: {user?.user_type?.toUpperCase()}</p>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon">📚</div>
          <div className="stat-info">
            <h3>Total Courses</h3>
            <p className="stat-value">{stats.totalCourses}</p>
          </div>
        </div>

        {user?.user_type === 'student' && (
          <>
            <div className="stat-card">
              <div className="stat-icon">✅</div>
              <div className="stat-info">
                <h3>My Enrollments</h3>
                <p className="stat-value">{stats.myCourses}</p>
              </div>
            </div>

            <div className="stat-card">
              <div className="stat-icon">🎯</div>
              <div className="stat-info">
                <h3>Total Credits</h3>
                <p className="stat-value">{stats.totalCredits}</p>
              </div>
            </div>
          </>
        )}

        <div className="stat-card">
          <div className="stat-icon">📧</div>
          <div className="stat-info">
            <h3>Email</h3>
            <p className="stat-value-small">{user?.email}</p>
          </div>
        </div>
      </div>

      <div className="quick-actions">
        <h2>Quick Actions</h2>
        <div className="action-grid">
          <a href="/courses" className="action-card">
            <span className="action-icon">🔍</span>
            <h3>Browse Courses</h3>
            <p>View all available courses</p>
          </a>

          {user?.user_type === 'student' && (
            <a href="/my-courses" className="action-card">
              <span className="action-icon">📖</span>
              <h3>My Courses</h3>
              <p>View your enrollments</p>
            </a>
          )}

          {user?.user_type === 'admin' && (
            <a href="/admin" className="action-card">
              <span className="action-icon">⚙️</span>
              <h3>Admin Panel</h3>
              <p>Manage system</p>
            </a>
          )}

          <a href="/profile" className="action-card">
            <span className="action-icon">👤</span>
            <h3>Profile</h3>
            <p>View your profile</p>
          </a>
        </div>
      </div>
    </div>
  )
}

export default Dashboard
