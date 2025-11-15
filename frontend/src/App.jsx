import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { useAuthStore } from './store/authStore'
import Layout from './components/Layout'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Courses from './pages/Courses'
import MyCourses from './pages/MyCourses'
import Profile from './pages/Profile'
import AdminPanel from './pages/AdminPanel'
import './App.css'

function PrivateRoute({ children, requireAdmin = false }) {
  const { isAuthenticated, user } = useAuthStore()
  
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />
  }
  
  if (requireAdmin && user?.user_type !== 'admin') {
    return <Navigate to="/dashboard" replace />
  }
  
  return children
}

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/login" element={<Login />} />
        
        <Route path="/" element={
          <PrivateRoute>
            <Layout />
          </PrivateRoute>
        }>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="courses" element={<Courses />} />
          <Route path="my-courses" element={<MyCourses />} />
          <Route path="profile" element={<Profile />} />
          <Route path="admin" element={
            <PrivateRoute requireAdmin={true}>
              <AdminPanel />
            </PrivateRoute>
          } />
        </Route>
      </Routes>
    </Router>
  )
}

export default App
