import { useAuthStore } from '../store/authStore'
import './Profile.css'

function Profile() {
  const { user } = useAuthStore()

  return (
    <div className="profile-page">
      <div className="page-header">
        <h1>👤 My Profile</h1>
        <p>Your account information</p>
      </div>

      <div className="profile-card">
        <div className="profile-avatar">
          {user?.full_name?.charAt(0).toUpperCase()}
        </div>

        <div className="profile-info">
          <div className="info-group">
            <label>Full Name</label>
            <p>{user?.full_name}</p>
          </div>

          <div className="info-group">
            <label>Username</label>
            <p>{user?.username}</p>
          </div>

          <div className="info-group">
            <label>Email</label>
            <p>{user?.email}</p>
          </div>

          <div className="info-group">
            <label>User Type</label>
            <p className="user-type-badge">{user?.user_type?.toUpperCase()}</p>
          </div>

          <div className="info-group">
            <label>Account Status</label>
            <p className={user?.is_active ? 'status-active' : 'status-inactive'}>
              {user?.is_active ? '✅ Active' : '❌ Inactive'}
            </p>
          </div>

          <div className="info-group">
            <label>User ID</label>
            <p className="user-id">{user?.user_id}</p>
          </div>
        </div>
      </div>
    </div>
  )
}

export default Profile
