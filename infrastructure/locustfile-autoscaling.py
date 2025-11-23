"""
Locust Load Test for Auto-Scaling Trigger
This generates sufficient load to trigger AWS Auto-Scaling policies

Scaling triggers:
1. CPU > 70% average
2. Requests > 1000 per target per minute

Run with:
locust -f infrastructure/locustfile-autoscaling.py --host=http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com
"""

from locust import HttpUser, task, between, events
import random
import time

# Track metrics
request_count = 0
error_count = 0
start_time = None


@events.init.add_listener
def on_locust_init(environment, **kwargs):
    """Initialize test"""
    global start_time
    start_time = time.time()


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Print test info at start"""
    print("\n" + "="*60)
    print("  AUTO-SCALING LOAD TEST")
    print("="*60)
    print(f"Target: {environment.host}")
    print(f"Goal: Trigger auto-scaling (CPU > 70% or Requests > 1000/target)")
    print("="*60 + "\n")


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Print summary at end"""
    elapsed = time.time() - start_time
    print("\n" + "="*60)
    print("  TEST COMPLETED")
    print("="*60)
    print(f"Duration: {elapsed:.1f} seconds")
    print(f"Total requests: {request_count}")
    print(f"Errors: {error_count}")
    print(f"Success rate: {((request_count - error_count) / request_count * 100):.2f}%")
    print(f"Avg RPS: {request_count / elapsed:.1f}")
    print("\nCheck AWS Console for auto-scaling activity!")
    print("="*60 + "\n")


class CourseRegistrationUser(HttpUser):
    """Simulates realistic user behavior with varying load"""
    
    # Wait time between requests (seconds)
    wait_time = between(0.1, 0.5)
    
    def on_start(self):
        """Called when a user starts"""
        self.semester = random.choice(["202401", "202402"])
        self.token = None
        
        # Try to login
        try:
            response = self.client.post("/api/auth/login", json={
                "username": "student1",
                "password": "student123"
            }, catch_response=True)
            
            if response.status_code == 200:
                data = response.json()
                self.token = data.get("access_token")
                response.success()
            else:
                # Continue without auth for public endpoints
                response.failure(f"Login failed: {response.status_code}")
        except Exception as e:
            print(f"Login error: {e}")
    
    @task(10)
    def health_check(self):
        """Health check endpoint - lightweight, frequent"""
        global request_count
        request_count += 1
        
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                global error_count
                error_count += 1
                response.failure(f"Status: {response.status_code}")
    
    @task(5)
    def list_courses_semester_1(self):
        """List courses for semester 202401"""
        global request_count
        request_count += 1
        
        with self.client.get("/api/courses?semester=202401", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                global error_count
                error_count += 1
                response.failure(f"Status: {response.status_code}")
    
    @task(5)
    def list_courses_semester_2(self):
        """List courses for semester 202402"""
        global request_count
        request_count += 1
        
        with self.client.get("/api/courses?semester=202402", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                global error_count
                error_count += 1
                response.failure(f"Status: {response.status_code}")
    
    @task(3)
    def list_enrollments(self):
        """Check enrollments - requires auth"""
        global request_count
        request_count += 1
        
        headers = {}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        
        with self.client.get(
            f"/api/enrollments-simple/my-enrollments?semester={self.semester}",
            headers=headers,
            catch_response=True
        ) as response:
            if response.status_code in [200, 401]:  # 401 is ok (no auth)
                response.success()
            else:
                global error_count
                error_count += 1
                response.failure(f"Status: {response.status_code}")
    
    @task(2)
    def api_root(self):
        """API root endpoint"""
        global request_count
        request_count += 1
        
        with self.client.get("/", catch_response=True) as response:
            # Any response is ok
            response.success()
    
    @task(1)
    def cpu_intensive_query(self):
        """Simulate CPU-intensive operation"""
        global request_count
        request_count += 1
        
        # Query multiple semesters rapidly
        semesters = ["202401", "202402", "202301"]
        for sem in semesters:
            with self.client.get(f"/api/courses?semester={sem}", catch_response=True) as response:
                if response.status_code == 200:
                    response.success()
                else:
                    global error_count
                    error_count += 1
                    response.failure(f"Status: {response.status_code}")


class HeavyLoadUser(HttpUser):
    """High-frequency user to maximize load"""
    
    wait_time = between(0.05, 0.1)  # Very short wait time
    weight = 2  # This user type has higher weight
    
    @task(20)
    def rapid_health_checks(self):
        """Rapid fire health checks"""
        global request_count
        request_count += 1
        
        self.client.get("/health")
    
    @task(10)
    def rapid_course_queries(self):
        """Rapid course queries"""
        global request_count
        request_count += 1
        
        semester = random.choice(["202401", "202402"])
        self.client.get(f"/api/courses?semester={semester}")


# Configuration for different test scenarios
class LightLoadUser(HttpUser):
    """Light load user for initial testing"""
    
    wait_time = between(1, 3)
    weight = 1
    
    @task
    def browse(self):
        global request_count
        request_count += 1
        self.client.get("/health")
