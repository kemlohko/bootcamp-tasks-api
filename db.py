import asyncpg
import os

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    f"postgresql://{os.environ.get('DB_USER', 'postgres')}:"
    f"{os.environ.get('DB_PASSWORD', 'postgres')}@"
    f"{os.environ.get('DB_HOST', 'localhost')}:"
    f"{os.environ.get('DB_PORT', '5432')}/"
    f"{os.environ.get('DB_NAME', 'taskly')}"
)

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    done BOOLEAN NOT NULL DEFAULT false,
    priority TEXT
)
"""

pool: asyncpg.Pool | None = None

async def connect():
    global pool
    pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=10)
    async with pool.acquire() as conn:
        await conn.execute(CREATE_TABLE_SQL)

async def disconnect():
    await pool.close()

async def list_tasks():
    async with pool.acquire() as conn:
        rows = await conn.fetch("SELECT id, title, description, done, priority FROM tasks ORDER BY id")
    return [dict(row) for row in rows]

async def create_task(title, description, done, priority):
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            INSERT INTO tasks (title, description, done, priority)
            VALUES ($1, $2, $3, $4)
            RETURNING id, title, description, done, priority
            """,
            title, description, done, priority
        )
    return dict(row)

async def get_task(task_id: int):
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, title, description, priority FROM tasks WHERE id = $1", task_id
        )
    return dit(row) if row else None

async def update_task(task_id: int, title, description, done, priority):
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            UPDATE tasks SET title = $1, description = $2, done = $3, priority = $4
            WHERE id = $5
            RETURNING id, title, description, done, priority
            """,
            title, description, done, priority, task_id
        )
    return dict(row) if row else None

async def delete_task(task_id: int) -> bool:
    async with pool.acquire() as conn:
        result = await conn.execute("DELETE FROM tasks WHERE id = $1", task_id)
    return result != "DELETE 0"

async def ping() -> bool:
    async with pool.acquire() as conn:
        await conn.fetchval("SELECT 1")
    return True

