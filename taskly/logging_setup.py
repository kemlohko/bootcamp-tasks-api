import logging
import json
import uuid
import contextvars

# Contextvar automatically scopes a trace ID to the current request
trace_id_var: contextvars.ContextVar[str] = contextvars.ContextVar("trace_id", default="-")

class JSONFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps ({
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "message": record.getMessage(),
            "trace_id": trace_id_var.get(),
        })

def setup_logging():
    handler = logging.StreamHandler()
    handler.setFormatter(JSONFormatter())
    logger = logging.getLogger("tasks-api")
    logger.setLevel(logging.INFO)
    logger.addHandler(handler)
    return logger

logger = setup_logging()