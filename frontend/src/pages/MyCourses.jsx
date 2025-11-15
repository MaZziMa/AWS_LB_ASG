import { useEffect, useState } from 'react'
import { enrollmentsAPI } from '../api/enrollments'
import './MyCourses.css'

function MyCourses() {
  const [enrollments, setEnrollments] = useState([])
  const [loading, setLoading] = useState(true)
  const [dropping, setDropping] = useState(null)

  useEffect(() => {
    loadEnrollments()
  }, [])

  const loadEnrollments = async () => {
    try {
      const data = await enrollmentsAPI.getMyEnrollments()
      setEnrollments(data)
    } catch (error) {
      console.error('Failed to load enrollments:', error)
      alert('Failed to load your courses')
    } finally {
      setLoading(false)
    }
  }

  const handleDrop = async (enrollmentId, courseName) => {
    if (!confirm(`Are you sure you want to drop "${courseName}"?`)) return

    setDropping(enrollmentId)
    try {
      await enrollmentsAPI.dropCourse(enrollmentId)
      alert('Course dropped successfully!')
      loadEnrollments()
    } catch (error) {
      alert(error.response?.data?.detail || 'Failed to drop course')
    } finally {
      setDropping(null)
    }
  }

  const totalCredits = enrollments.reduce((sum, e) => sum + (e.course?.credits || 0), 0)

  if (loading) {
    return <div className="loading">Loading your courses...</div>
  }

  return (
    <div className="my-courses-page">
      <div className="page-header">
        <h1>📖 My Courses</h1>
        <p>Your enrolled courses for this semester</p>
      </div>

      <div className="credits-summary">
        <div className="summary-card">
          <span className="summary-label">Total Enrollments:</span>
          <span className="summary-value">{enrollments.length}</span>
        </div>
        <div className="summary-card">
          <span className="summary-label">Total Credits:</span>
          <span className="summary-value">{totalCredits}</span>
        </div>
      </div>

      {enrollments.length === 0 ? (
        <div className="no-enrollments">
          <p>You haven't enrolled in any courses yet.</p>
          <a href="/courses" className="btn-primary">Browse Courses</a>
        </div>
      ) : (
        <div className="enrollments-list">
          {enrollments.map((enrollment) => (
            <div key={enrollment.enrollment_id} className="enrollment-card">
              <div className="enrollment-header">
                <div>
                  <h3>{enrollment.course?.course_code}</h3>
                  <h2>{enrollment.course?.course_name}</h2>
                </div>
                <span className="enrollment-status">
                  {enrollment.status === 'enrolled' ? '✅ Enrolled' : enrollment.status}
                </span>
              </div>

              <div className="enrollment-info">
                <div className="info-row">
                  <span className="info-label">Department:</span>
                  <span>{enrollment.course?.department}</span>
                </div>
                <div className="info-row">
                  <span className="info-label">Credits:</span>
                  <span>{enrollment.course?.credits}</span>
                </div>
                <div className="info-row">
                  <span className="info-label">Semester:</span>
                  <span>{enrollment.semester}</span>
                </div>
                <div className="info-row">
                  <span className="info-label">Enrolled Date:</span>
                  <span>{new Date(enrollment.enrollment_date).toLocaleDateString()}</span>
                </div>
                {enrollment.grade && (
                  <div className="info-row">
                    <span className="info-label">Grade:</span>
                    <span className="grade">{enrollment.grade}</span>
                  </div>
                )}
              </div>

              <p className="course-description">{enrollment.course?.description}</p>

              <div className="enrollment-actions">
                <button
                  className="btn-drop"
                  onClick={() => handleDrop(enrollment.enrollment_id, enrollment.course?.course_name)}
                  disabled={dropping === enrollment.enrollment_id}
                >
                  {dropping === enrollment.enrollment_id ? 'Dropping...' : 'Drop Course'}
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default MyCourses
