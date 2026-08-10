import redis.asyncio as redis
import os
import json

REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = os.environ.get("REDIS_PORT", "6379")
REDIS_URL = f"redis://{REDIS_HOST}:{REDIS_PORT}"

TTL_SECONDS = 60 # How long a cached value is trusted before it's considered stale

client: redis.Redis | None = None

async def connect():
    global client
    client = redis.from_url(REDIS_URL, decode_responses=True)

async def disconnect():
    await client.close()

async def get(key: str):
    raw = await client.get(key)
    return json.loads(raw) if raw else None

async def set(key: str, value, ttl: int = TTL_SECONDS):
    await client.set(key, json.dumps(value), ex=ttl)

async def delete(key: str):
    await client.delete(key)

async def delete_pattern(pattern: str):
    # Used to invalidate all "tasks:list*" style keys at once
    async for key in client.scan_iter(match=pattern):
        await client.delete(key)