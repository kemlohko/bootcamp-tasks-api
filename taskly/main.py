from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
from typing import List
from contextlib import asynccontextmanager
import db, cache, metrics
from task import Task, TaskOut
import time, uuid
from logging_setup import logger, trace_id_var

@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.connect()
    await cache.connect()
    yield
    await cache.disconnect()
    await db.disconnect()
    

app = FastAPI(lifespan=lifespan, title="Tasks API", description="Bootcamp demo app — Week 1/2/8")

@app.middleware("http")
async def track_metrics(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    duration = time.perf_counter() - start

    # Use the route template (e.g. "/tasks/{task_id}") instead of the raw
    # path, so metric cardinality doesn't grow with every unique task ID
    route = request.scope.get("route")
    path = route.path if route else request.url.path

    metrics.REQUEST_COUNT.labels(
        method=request.method, path=path, status_code=response.status_code
    ).inc()
    metrics.REQUEST_DURATION.labels(
        method=request.method, path=path
    ).observe(duration)

    return response

@app.middleware("http")
async def add_trace_id(request: Request, call_next):
    trace_id = str(uuid.uuid4())
    token = trace_id_var.set(trace_id) # makes trace_id available everywhere in this request

    response = await call_next(request)

    response.headers["X-Trace-ID"] = trace_id # so the client can see/report it too
    logger.info(f"{request.method} {request.url.path} -> {response.status_code}")

    trace_id_var.reset(token) # clean up after the request finishes
    return response



@app.get("/metrics")
async def get_metrics():
    data, content_type = metrics.get_metrics()
    return Response(content=data, media_type=content_type)

@app.get("/health")
async def health():
    try:
        await db.ping()
        return {"status": "ok", "service": "tasks-api"}
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        raise HTTPException(status_code=503, detail="database unavailable")


@app.get("/tasks", response_model=List[TaskOut])
async def list_tasks():
    result = await db.list_tasks()
    logger.info(f"Listed {len(result)} tasks")
    return result


@app.post("/tasks", response_model=TaskOut, status_code=201)
async def create_task(task: Task):
   result = await db.create_task(task.title, task.description, task.done, task.priority)
   metrics.TASKS_CREATED.inc()
   metrics.TASKS_ACTIVE.inc()
   logger.info(f"Created task id={result['id']} title={result['title']!r}")
   return result


@app.get("/tasks/{task_id}", response_model=TaskOut)
async def get_task(task_id: int):
    result = await db.get_task(task_id)
    if result is None:
        logger.warning(f"Task not found: id={task_id}")
        raise HTTPException(status_code=404, detail="Task not found")
    return result


@app.patch("/tasks/{task_id}", response_model=TaskOut)
async def update_task(task_id: int, task: Task):
    result = await db.update_task(task_id, task.title, task.description, task.done, task.priority)
    if result is None:
        logger.warning(f"Update failed, task not found: id={task_id}")
        raise HTTPException(status_code=404, detail="Task not found")
    logger.info(f"Updated task id={task_id}")
    return result


@app.delete("/tasks/{task_id}", status_code=204)
async def delete_task(task_id: int):
    deleted = await db.delete_task(task_id) 
    if not deleted:
        raise HTTPException(status_code=404, detail="Task not found")
    metrics.TASKS_ACTIVE.dec()
