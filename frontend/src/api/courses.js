import api from './axios'

export const coursesAPI = {
  getAllCourses: async (semester = null) => {
    const params = semester ? { semester } : {}
    const response = await api.get('/courses', { params })
    return response.data
  },
  
  getCourse: async (courseId) => {
    const response = await api.get(`/courses/${courseId}`)
    return response.data
  },
  
  createCourse: async (courseData) => {
    const response = await api.post('/courses', courseData)
    return response.data
  },
  
  updateCourse: async (courseId, courseData) => {
    const response = await api.put(`/courses/${courseId}`, courseData)
    return response.data
  },
  
  deleteCourse: async (courseId) => {
    const response = await api.delete(`/courses/${courseId}`)
    return response.data
  }
}
