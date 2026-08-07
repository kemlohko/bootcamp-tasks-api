from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, List
import os

app = FastAPI(title="Tasks API", description="Bootcamp demo app — Week 1/2/8")

# In-memory store for simplicity (Week 2 labs add a real database)
tasks: dict[int, dict] = {}
next_id = 1


class Task(BaseModel):
    title: str
    description: Optional[str] = None
    done: bool = False
    priority: Optional[str] = None  # "low" | "medium" | "high" — set manually or by the priority-classifier model


class TaskOut(Task):
    id: int


@app.get("/health")
def health():
    return {"status": "ok", "service": "tasks-api"}


@app.get("/tasks", response_model=List[TaskOut])
def list_tasks():
    return [{"id": k, **v} for k, v in tasks.items()]


@app.post("/tasks", response_model=TaskOut, status_code=201)
def create_task(task: Task):
    global next_id
    tasks[next_id] = task.model_dump()
    result = {"id": next_id, **tasks[next_id]}
    next_id += 1
    return result


@app.get("/tasks/{task_id}", response_model=TaskOut)
def get_task(task_id: int):
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    return {"id": task_id, **tasks[task_id]}


@app.patch("/tasks/{task_id}", response_model=TaskOut)
def update_task(task_id: int, task: Task):
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    tasks[task_id] = task.model_dump()
    return {"id": task_id, **tasks[task_id]}


@app.delete("/tasks/{task_id}", status_code=204)
def delete_task(task_id: int):
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    del tasks[task_id]
