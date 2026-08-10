from prometheus_client import Counter, Gauge, Histogram, CONTENT_TYPE_LATEST, generate_latest

# Request count, broken down by method, path and status code
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "path", "status_code"],
)

# Request duration histogram, for p95/p99 latency in Grafana
REQUEST_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "path"],
)

# Custom business metric - total number of tasks ever been created
TASKS_CREATED = Counter(
    "tasks_created_total",
    "Total number of tasks created",
)

# Custom business metric - tasks active
TASKS_ACTIVE = Counter(
    "tasks_active",
    "Current number of tasks in the database",
)

def get_metrics():
    return generate_latest(), CONTENT_TYPE_LATEST