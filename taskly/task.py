from pydantic import BaseModel
from typing import Optional, List

class Task(BaseModel):
    title: str
    description: Optional[str] = None
    done: bool = False
    priority: Optional[str] = None  # "low" | "medium" | "high" — set manually or by the priority-classifier model


class TaskOut(Task):
    id: int
