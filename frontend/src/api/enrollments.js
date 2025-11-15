import api from './axios'

export const enrollmentsAPI = {
  getMyEnrollments: async () => {
    const response = await api.get('/enrollments/my-enrollments')
    return response.data
  },
  
  enrollCourse: async (courseId) => {
    const response = await api.post('/enrollments', { course_id: courseId })
    return response.data
  },
  
  dropCourse: async (enrollmentId) => {
    const response = await api.delete(`/enrollments/${enrollmentId}`)
    return response.data
  },
  
  getEnrollmentsByCourse: async (courseId) => {
    const response = await api.get(`/enrollments/course/${courseId}`)
    return response.data
  }
}
