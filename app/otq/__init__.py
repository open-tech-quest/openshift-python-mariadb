"""Open Tech Quest - OpenShift Python/MariaDB demo application."""

import logging
import os

import pymysql
from flask import Flask, render_template

log = logging.getLogger(__name__)


def _db_config() -> dict:
    return {
        "host": os.environ.get("DB_HOST", "localhost"),
        "port": int(os.environ.get("DB_PORT", "3306")),
        "user": os.environ.get("DB_USER", "otq"),
        "password": os.environ.get("DB_PASSWORD", ""),
        "database": os.environ.get("DB_NAME", "otq"),
        "connect_timeout": int(os.environ.get("DB_CONNECT_TIMEOUT", "3")),
        "read_timeout": 5,
        "charset": "utf8mb4",
    }


def _connect() -> pymysql.connections.Connection:
    return pymysql.connect(**_db_config())


def fetch_flag(challenge_name: str) -> str | None:
    """Return the flag of the given challenge, or None if there is no such row."""
    with _connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT flag FROM challenge WHERE name = %s", (challenge_name,))
        row = cur.fetchone()
    return row[0] if row else None


def _setup_logging() -> None:
    """Send this package's log records to gunicorn's error log (stderr), or stderr when run standalone."""
    gunicorn_logger = logging.getLogger("gunicorn.error")
    pkg_logger = logging.getLogger(__package__)
    if gunicorn_logger.handlers:
        pkg_logger.handlers = gunicorn_logger.handlers
        pkg_logger.setLevel(gunicorn_logger.level)
        pkg_logger.propagate = False
    else:
        logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(levelname)s] %(name)s: %(message)s")


def create_app() -> Flask:
    _setup_logging()
    app = Flask(__name__)
    challenge_name = os.environ.get("CHALLENGE_NAME", "openshift-python-mariadb")

    @app.get("/")
    def index():
        flag, error = None, None
        try:
            flag = fetch_flag(challenge_name)
            if flag is None:
                error = f"No challenge named '{challenge_name}' found in the database."
        except pymysql.MySQLError as exc:
            log.warning("Database query failed: %s", exc)
            error = f"Cannot read the challenge flag from the database: {exc.args[-1] if exc.args else exc}"
        return render_template("index.html", flag=flag, error=error), (200 if flag else 503)

    @app.get("/healthz")
    def healthz():
        return {"status": "ok"}

    @app.get("/readyz")
    def readyz():
        try:
            with _connect() as conn:
                conn.ping(reconnect=False)
        except pymysql.MySQLError as exc:
            log.warning("Readiness check failed, database unavailable: %s", exc)
            return {"status": "database unavailable", "error": str(exc)}, 503
        return {"status": "ok"}

    return app
