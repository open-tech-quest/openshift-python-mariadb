import os

bind = f"0.0.0.0:{os.environ.get('PORT', '8080')}"
workers = int(os.environ.get("GUNICORN_WORKERS", "2"))
threads = int(os.environ.get("GUNICORN_THREADS", "4"))
accesslog = "-"
errorlog = "-"
# No writable /dev/shm guarantee in restricted containers
worker_tmp_dir = "/tmp"
