import { useEffect, useState } from 'react'
import { useAuthStore } from '../store/authStore'
import { coursesAPI } from '../api/courses'
import { enrollmentsAPI } from '../api/enrollments'
import './Courses.css'

function Courses() {
  const { user } = useAuthStore()
  const [courses, setCourses] = useState([])
  const [enrollments, setEnrollments] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('')
  const [enrolling, setEnrolling] = useState(null)

  useEffect(() => {
    loadCourses()
  }, [])

  const loadCourses = async () => {
    try {
      const [coursesData, enrollmentsData] = await Promise.all([
        coursesAPI.getAllCourses(),
        user.user_type === 'student' ? enrollmentsAPI.getMyEnrollments() : Promise.resolve([])
      ])
      
      // Ensure coursesData is an array
      setCourses(Array.isArray(coursesData) ? coursesData : [])
      setEnrollments(Array.isArray(enrollmentsData) ? enrollmentsData : [])
    } catch (error) {
      console.error('Failed to load courses:', error)
      alert('Failed to load courses')
      setCourses([])
      setEnrollments([])
    } finally {
      setLoading(false)
    }
  }

  const isEnrolled = (courseId) => {
    return enrollments.some(e => e.course_id === courseId)
  }

  const handleEnroll = async (courseId) => {
    if (!confirm('Are you sure you want to enroll in this course?')) return

    setEnrolling(courseId)
    try {
      await enrollmentsAPI.enrollCourse(courseId)
      alert('Enrolled successfully!')
      loadCourses()
    } catch (error) {
      alert(error.response?.data?.detail || 'Failed to enroll')
    } finally {
      setEnrolling(null)
    }
  }

  const filteredCourses = courses.filter(course =>
    course.course_name?.toLowerCase().includes(filter.toLowerCase()) ||
    course.course_code?.toLowerCase().includes(filter.toLowerCase()) ||
    course.department?.toLowerCase().includes(filter.toLowerCase())
  )

  if (loading) {
    return <div className="loading">Loading courses...</div>
  }

  return (
    <div className="courses-page">
      <div className="page-header">
        <h1>📚 All Courses</h1>
        <p>Browse and enroll in available courses</p>
      </div>

      <div className="courses-filters">
        <input
          type="text"
          placeholder="🔍 Search courses by name, code, or department..."
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          className="search-input"
        />
      </div>

      <div className="courses-count">
        Showing {filteredCourses.length} of {courses.length} courses
      </div>

      <div className="courses-grid">
        {filteredCourses.map((course) => (
          <div key={course.course_id} className="course-card">
            <div className="course-header">
              <h3>{course.course_code}</h3>
              <span className="course-credits">{course.credits} credits</span>
            </div>
            
            <h2 className="course-name">{course.course_name}</h2>
            
            <div className="course-info">
              <div className="info-item">
                <span className="info-label">Department:</span>
                <span>{course.department}</span>
              </div>
              <div className="info-item">
                <span className="info-label">Semester:</span>
                <span>{course.semester}</span>
              </div>
              <div className="info-item">
                <span className="info-label">Capacity:</span>
                <span>{course.enrolled_count || 0} / {course.max_students}</span>
              </div>
            </div>

            <p className="course-description">{course.description}</p>

            {user.user_type === 'student' && (
              <div className="course-actions">
                {isEnrolled(course.course_id) ? (
                  <button className="btn-enrolled" disabled>
                    ✅ Enrolled
                  </button>
                ) : (
                  <button
                    className="btn-enroll"
                    onClick={() => handleEnroll(course.course_id)}
                    disabled={enrolling === course.course_id || 
                              (course.enrolled_count >= course.max_students)}
                  >
                    {enrolling === course.course_id ? 'Enrolling...' : 
                     (course.enrolled_count >= course.max_students) ? 'Full' : 'Enroll'}
                  </button>
                )}
              </div>
            )}
          </div>
        ))}
      </div>

      {filteredCourses.length === 0 && (
        <div className="no-results">
          <p>No courses found matching your search.</p>
        </div>
      )}
    </div>
  )
}

export default Courses
