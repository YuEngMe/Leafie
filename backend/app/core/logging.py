import logging
from logging.config import dictConfig
from typing import Any

from app.core.request_context import get_request_id


class RequestContextFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = get_request_id() or "-"
        return True


def configure_logging(level: str) -> None:
    config: dict[str, Any] = {
        "version": 1,
        "disable_existing_loggers": False,
        "filters": {
            "request_context": {
                "()": "app.core.logging.RequestContextFilter",
            }
        },
        "formatters": {
            "default": {
                "format": "%(asctime)s %(levelname)s %(name)s request_id=%(request_id)s %(message)s"
            }
        },
        "handlers": {
            "default": {
                "class": "logging.StreamHandler",
                "filters": ["request_context"],
                "formatter": "default",
            }
        },
        "root": {
            "handlers": ["default"],
            "level": level.upper(),
        },
    }
    dictConfig(config)
