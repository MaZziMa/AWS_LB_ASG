from locust import HttpUser, task, between, events
from random import choice
import os

# Test users seeded in DynamoDB
STUDENTS = [
    {"username": "student1", "password": "student123"},
    {"username": "student2", "password": "student123"},
]

class CourseRegUser(HttpUser):
    wait_time = between(0.5, 2.0)

    def on_start(self):
        creds = choice(STUDENTS)
        res = self.client.post(
            "/api/auth/login",
            json={"username": creds["username"], "password": creds["password"]},
            name="POST /api/auth/login",
        )
        self.token = None
        self.headers = {}
        if res.status_code == 200:
            data = res.json()
            self.token = data.get("access_token")
            if self.token:
                self.headers = {"Authorization": f"Bearer {self.token}"}
        else:
            # Count failed logins explicitly
            events.request.fire(
                request_type="POST",
                name="/api/auth/login (fail)",
                response_time=res.elapsed.total_seconds() * 1000 if res.elapsed else 0,
                response_length=len(res.text or ""),
                exception=Exception(f"Login failed: {res.status_code}"),
            )

    @task(3)
    def list_courses(self):
        self.client.get("/api/courses", headers=self.headers, name="GET /api/courses")

    @task(2)
    def my_enrollments(self):
        self.client.get(
            "/api/enrollments/my-enrollments",
            headers=self.headers,
            name="GET /api/enrollments/my-enrollments",
        )

    @task(1)
    def enroll_random_course(self):
        # Get courses and pick one to enroll
        r = self.client.get("/api/courses", headers=self.headers, name="GET /api/courses (for enroll)")
        if r.status_code == 200:
            try:
                courses = r.json()
                if isinstance(courses, list) and courses:
                    course_id = choice(courses)["course_id"]
                    self.client.post(
                        "/api/enrollments",
                        json={"course_id": course_id},
                        headers=self.headers,
                        name="POST /api/enrollments",
                    )
            except Exception:
                pass

    @task(1)
    def profile(self):
        self.client.get("/api/auth/me", headers=self.headers, name="GET /api/auth/me")
