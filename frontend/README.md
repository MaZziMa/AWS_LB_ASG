# Course Registration System - Frontend

React + Vite frontend application for the Course Registration System.

## 🚀 Quick Start

### Installation

```bash
cd frontend
npm install
```

### Development

```bash
npm run dev
```

Application will run on: http://localhost:3000

### Build for Production

```bash
npm run build
npm run preview
```

## 📋 Features

- **Authentication**: JWT-based login system
- **Dashboard**: Overview with statistics
- **Course Browsing**: View all available courses
- **Enrollment Management**: Enroll and drop courses
- **Admin Panel**: Create and manage courses (admin only)
- **User Profile**: View account information

## 🔐 Demo Accounts

- **Admin**: `admin` / `admin123`
- **Teacher**: `teacher1` / `teacher123`
- **Student**: `student1` / `student123`

## 🛠️ Tech Stack

- **React 18**: UI framework
- **Vite**: Build tool
- **React Router**: Navigation
- **Zustand**: State management
- **Axios**: HTTP client

## 📁 Project Structure

```
frontend/
├── src/
│   ├── api/           # API client functions
│   ├── components/    # Reusable components
│   ├── pages/         # Page components
│   ├── store/         # Zustand state management
│   ├── App.jsx        # Main app component
│   └── main.jsx       # Entry point
├── index.html
├── package.json
└── vite.config.js
```

## 🔗 API Integration

The frontend connects to the backend API at `http://localhost:8000/api`.

Make sure the backend server is running before starting the frontend.

## 📝 Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint

## 🌐 Pages

- `/login` - Login page
- `/dashboard` - Dashboard (after login)
- `/courses` - Browse all courses
- `/my-courses` - View enrolled courses
- `/profile` - User profile
- `/admin` - Admin panel (admin only)
