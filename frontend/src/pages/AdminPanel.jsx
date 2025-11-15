import { useEffect, useState } from 'react'
import { coursesAPI } from '../api/courses'
import './AdminPanel.css'

function AdminPanel() {
  const [courses, setCourses] = useState([])
  const [loading, setLoading] = useState(true)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const [formData, setFormData] = useState({
    course_code: '',
    course_name: '',
    department: '',
    credits: 3,
    description: '',
    semester: 'Fall 2025',
    max_students: 30
  })

  useEffect(() => {
    loadCourses()
  }, [])

  const loadCourses = async () => {
    try {
      const data = await coursesAPI.getAllCourses()
      setCourses(data)
    } catch (error) {
      console.error('Failed to load courses:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleCreateCourse = async (e) => {
    e.preventDefault()
    try {
      await coursesAPI.createCourse(formData)
      alert('Course created successfully!')
      setShowCreateModal(false)
      setFormData({
        course_code: '',
        course_name: '',
        department: '',
        credits: 3,
        description: '',
        semester: 'Fall 2025',
        max_students: 30
      })
      loadCourses()
    } catch (error) {
      alert(error.response?.data?.detail || 'Failed to create course')
    }
  }

  const handleDeleteCourse = async (courseId, courseName) => {
    if (!confirm(`Are you sure you want to delete "${courseName}"?`)) return

    try {
      await coursesAPI.deleteCourse(courseId)
      alert('Course deleted successfully!')
      loadCourses()
    } catch (error) {
      alert(error.response?.data?.detail || 'Failed to delete course')
    }
  }

  if (loading) {
    return <div className="loading">Loading admin panel...</div>
  }

  return (
    <div className="admin-page">
      <div className="page-header">
        <h1>⚙️ Admin Panel</h1>
        <button className="btn-primary" onClick={() => setShowCreateModal(true)}>
          + Create New Course
        </button>
      </div>

      <div className="admin-stats">
        <div className="stat-box">
          <h3>Total Courses</h3>
          <p className="stat-number">{courses.length}</p>
        </div>
        <div className="stat-box">
          <h3>Total Enrollments</h3>
          <p className="stat-number">
            {courses.reduce((sum, c) => sum + (c.enrolled_count || 0), 0)}
          </p>
        </div>
      </div>

      <div className="courses-table-container">
        <h2>All Courses</h2>
        <table className="courses-table">
          <thead>
            <tr>
              <th>Code</th>
              <th>Name</th>
              <th>Department</th>
              <th>Credits</th>
              <th>Semester</th>
              <th>Enrolled/Max</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {courses.map((course) => (
              <tr key={course.course_id}>
                <td>{course.course_code}</td>
                <td>{course.course_name}</td>
                <td>{course.department}</td>
                <td>{course.credits}</td>
                <td>{course.semester}</td>
                <td>{course.enrolled_count || 0} / {course.max_students}</td>
                <td>
                  <button
                    className="btn-delete"
                    onClick={() => handleDeleteCourse(course.course_id, course.course_name)}
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showCreateModal && (
        <div className="modal-overlay" onClick={() => setShowCreateModal(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h2>Create New Course</h2>
            <form onSubmit={handleCreateCourse}>
              <div className="form-group">
                <label>Course Code *</label>
                <input
                  type="text"
                  value={formData.course_code}
                  onChange={(e) => setFormData({...formData, course_code: e.target.value})}
                  required
                />
              </div>

              <div className="form-group">
                <label>Course Name *</label>
                <input
                  type="text"
                  value={formData.course_name}
                  onChange={(e) => setFormData({...formData, course_name: e.target.value})}
                  required
                />
              </div>

              <div className="form-group">
                <label>Department *</label>
                <input
                  type="text"
                  value={formData.department}
                  onChange={(e) => setFormData({...formData, department: e.target.value})}
                  required
                />
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label>Credits *</label>
                  <input
                    type="number"
                    value={formData.credits}
                    onChange={(e) => setFormData({...formData, credits: parseInt(e.target.value)})}
                    min="1"
                    max="6"
                    required
                  />
                </div>

                <div className="form-group">
                  <label>Max Students *</label>
                  <input
                    type="number"
                    value={formData.max_students}
                    onChange={(e) => setFormData({...formData, max_students: parseInt(e.target.value)})}
                    min="1"
                    required
                  />
                </div>
              </div>

              <div className="form-group">
                <label>Semester *</label>
                <input
                  type="text"
                  value={formData.semester}
                  onChange={(e) => setFormData({...formData, semester: e.target.value})}
                  required
                />
              </div>

              <div className="form-group">
                <label>Description</label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({...formData, description: e.target.value})}
                  rows="3"
                />
              </div>

              <div className="modal-actions">
                <button type="button" className="btn-cancel" onClick={() => setShowCreateModal(false)}>
                  Cancel
                </button>
                <button type="submit" className="btn-primary">
                  Create Course
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

export default AdminPanel
