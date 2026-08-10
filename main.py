from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
from typing import List
from contextlib import asynccontextmanager
import db, cache, metrics
from task import Task, TaskOut
import time

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

@app.get("/metrics")
async def get_metrics():
    data, content_type = metrics.get_metrics()
    return Response(content=data, media_type=content_type)

@app.get("/health")
async def health():
    try:
        await db.ping()
        return {"status": "ok", "service": "tasks-api"}
    except Exception:
        raise HTTPException(status_code=503, detail="database unavailable")


@app.get("/tasks", response_model=List[TaskOut])
async def list_tasks():
    return await db.list_tasks()


@app.post("/tasks", response_model=TaskOut, status_code=201)
async def create_task(task: Task):
   result = await db.create_task(task.title, task.description, task.done, task.priority)
   metrics.TASKS_CREATED.inc()
   metrics.TASKS_ACTIVE.inc()
   return result


@app.get("/tasks/{task_id}", response_model=TaskOut)
async def get_task(task_id: int):
    result = await db.get_task(task_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return result


@app.patch("/tasks/{task_id}", response_model=TaskOut)
async def update_task(task_id: int, task: Task):
    result = await db.update_task(task_id, task.title, task.description, task.done, task.priority)
    if result is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return result


@app.delete("/tasks/{task_id}", status_code=204)
async def delete_task(task_id: int):
    deleted = await db.delete_task(task_id) 
    if not deleted:
        raise HTTPException(status_code=404, detail="Task not found")
    metrics.TASKS_ACTIVE.dec()
