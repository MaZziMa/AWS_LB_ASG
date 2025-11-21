import requests, time, random, threading, statistics
from datetime import datetime
from collections import defaultdict

API_HOST = "http://course-reg-alb-1073823580.us-east-1.elb.amazonaws.com"
USERS = [{"username": "student1", "password": "student123"}, {"username": "student2", "password": "student123"}]
stats = {"total_requests": 0, "successful_requests": 0, "failed_requests": 0, "response_times": [], "errors": defaultdict(int), "status_codes": defaultdict(int)}
stats_lock = threading.Lock()

class StressTestUser:
    def __init__(self, user_id, user_creds, duration_seconds):
        self.user_id = user_id
        self.username = user_creds["username"]
        self.password = user_creds["password"]
        self.duration_seconds = duration_seconds
        self.session = requests.Session()
        self.token = None
        self.stop_time = time.time() + duration_seconds
    
    def login(self):
        try:
            response = self.session.post(f"{API_HOST}/api/auth/login", json={"username": self.username, "password": self.password}, timeout=10)
            if response.status_code == 200:
                data = response.json()
                self.token = data.get("access_token")
                self.session.headers.update({"Authorization": f"Bearer {self.token}"})
                return True
            return False
        except: return False
    
    def _make_request(self, method, endpoint):
        start_time = time.time()
        try:
            url = f"{API_HOST}{endpoint}"
            response = self.session.get(url, timeout=10) if method == "GET" else self.session.post(url, timeout=10)
            elapsed = (time.time() - start_time) * 1000
            with stats_lock:
                stats["total_requests"] += 1
                stats["response_times"].append(elapsed)
                stats["status_codes"][response.status_code] += 1
                if 200 <= response.status_code < 300:
                    stats["successful_requests"] += 1
                    return True
                else:
                    stats["failed_requests"] += 1
                    return False
        except Exception as e:
            with stats_lock:
                stats["total_requests"] += 1
                stats["failed_requests"] += 1
                stats["errors"][str(type(e).__name__)] += 1
            return False
    
    def run(self):
        if not self.login(): return
        print(f"[User {self.user_id}] Started as {self.username}")
        tasks = ["list_courses"]*3 + ["my_enrollments"]*2 + ["enroll_random"]*1 + ["profile"]*1
        while time.time() < self.stop_time:
            task = random.choice(tasks)
            if task == "list_courses": self._make_request("GET", "/api/courses")
            elif task == "my_enrollments": self._make_request("GET", "/api/enrollments/my-enrollments")
            elif task == "profile": self._make_request("GET", "/api/auth/me")
            elif task == "enroll_random": self._make_request("POST", f"/api/enrollments/enroll/{random.randint(1,5)}")
            time.sleep(random.uniform(1, 3))
        print(f"[User {self.user_id}] Finished")

def print_stats():
    with stats_lock:
        total = stats["total_requests"]
        if total == 0: return
        success = stats["successful_requests"]
        failed = stats["failed_requests"]
        success_rate = (success / total) * 100
        rt = stats["response_times"]
        avg_time = statistics.mean(rt) if rt else 0
        min_time = min(rt) if rt else 0
        max_time = max(rt) if rt else 0
        print(f"\n{'='*70}\n{'STATS':^70}\n{'='*70}")
        print(f"Total: {total:,} | Success: {success:,} ({success_rate:.1f}%) | Failed: {failed:,}")
        print(f"Response Time (ms): Avg={avg_time:.1f} Min={min_time:.1f} Max={max_time:.1f}")
        print(f"Status Codes: {dict(stats['status_codes'])}")
        print(f"{'='*70}\n")

def run_stress_test(num_users=50, duration_minutes=5):
    duration_seconds = duration_minutes * 60
    print(f"\n{'='*70}\nStarting Stress Test\n{'='*70}")
    print(f"Users: {num_users} | Duration: {duration_minutes} min | API: {API_HOST}")
    print(f"Start: {datetime.now().strftime('%H:%M:%S')}\n{'='*70}\n")
    threads = []
    for i in range(num_users):
        user = StressTestUser(i+1, USERS[i % len(USERS)], duration_seconds)
        thread = threading.Thread(target=user.run)
        thread.start()
        threads.append(thread)
        time.sleep(0.1)
    start_time = time.time()
    while time.time() - start_time < duration_seconds:
        time.sleep(30)
        print_stats()
    for t in threads: t.join()
    print(f"\n{'='*70}\nFINAL RESULTS\n{'='*70}")
    print(f"End: {datetime.now().strftime('%H:%M:%S')}")
    print_stats()

if __name__ == "__main__":
    import sys
    users = int(sys.argv[1]) if len(sys.argv) > 1 else 50
    minutes = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    try: run_stress_test(users, minutes)
    except KeyboardInterrupt: print("\nTest interrupted!"); print_stats()
