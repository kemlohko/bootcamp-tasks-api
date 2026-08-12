import asyncpg
import os, json
import cache
from logging_setup import logger
import boto3


DB_SECRET_ARN = os.environ.get("DB_SECRET_ARN")


def get_db_password():
    if not DB_SECRET_ARN:
        return os.environ.get("DB_PASSWORD", "postgres")  # local dev fallback

    client = boto3.client("secretsmanager", region_name=os.environ.get("AWS_REGION", "us-east-1"))
    response = client.get_secret_value(SecretId=DB_SECRET_ARN)
    secret = json.loads(response["SecretString"])
    return secret["password"]


def build_database_url():
    password = get_db_password()
    return (
        f"postgresql://{os.environ.get('DB_USER', 'postgres')}:"
        f"{password}@"
        f"{os.environ.get('DB_HOST', 'localhost')}:"
        f"{os.environ.get('DB_PORT', '5432')}/"
        f"{os.environ.get('DB_NAME', 'taskly')}"
    )


DATABASE_URL = build_database_url()


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
    logger.info("Connecting to database...")
    try:
        pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=10)
        async with pool.acquire() as conn:
            await conn.execute(CREATE_TABLE_SQL)
        logger.info("Database connected and schema ready")
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        raise

async def disconnect():
    logger.info("Clossing database connection pool")
    await pool.close()

async def list_tasks():
    cached = await cache.get("tasks:list")
    if cached is not None:
        return cached

    async with pool.acquire() as conn:
        rows = await conn.fetch("SELECT id, title, description, done, priority FROM tasks ORDER BY id")
    result = [dict(row) for row in rows]

    await cache.set("tasks:list", result)
    return result

async def get_task(task_id: int):
    cached_key = f"tasks:{task_id}"
    cached = await cache.get(cached_key)
    if cached is not None:
        return cached

    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, title, description, done, priority FROM tasks WHERE id = $1", task_id
        )
    result =  dict(row) if row else None

    if result is not None:
        await cache.set(cached_key, result)
    return result

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
    await cache.delete("tasks:list") # list is now stale
    return dict(row)

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
    if row:
        await cache.delete("tasks:list")
        await cache.delete(f"tasks:{task_id}")
    return dict(row) if row else None

async def delete_task(task_id: int) -> bool:
    async with pool.acquire() as conn:
        result = await conn.execute("DELETE FROM tasks WHERE id = $1", task_id)
    deleted = result != "DELETE 0"
    if deleted:
        await cache.delete("tasks:list")
        await cache.delete(f"tasks:{task_id}")

async def ping() -> bool:
    async with pool.acquire() as conn:
        await conn.fetchval("SELECT 1")
    return True

