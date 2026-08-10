from fastapi import FastAPI, HTTPException
from typing import List
from contextlib import asynccontextmanager
import db
from task import Task, TaskOut

@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.connect()
    yield
    await db.disconnect()

app = FastAPI(lifespan=lifespan, title="Tasks API", description="Bootcamp demo app — Week 1/2/8")


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
   return await db.create_task(task.title, task.description, task.done, task.priority)


@app.get("/tasks/{task_id}", response_model=TaskOut)
async def get_task(task_id: int):
    result = await db.get_task(task_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Task not found")


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
