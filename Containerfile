# Build stage: install Python dependencies with pip (only available in the builder image)
FROM registry.access.redhat.com/hi/python:latest-builder AS builder
USER 0

WORKDIR /opt/app-root
COPY app/requirements.txt .
RUN python3 -m pip install --no-cache-dir --target /opt/app-root/deps -r requirements.txt

# Runtime stage: minimal hardened Python image (no shell, no pip)
FROM registry.access.redhat.com/hi/python:latest

ENV PYTHONPATH=/opt/app-root/deps:/opt/app-root/src \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

COPY --from=builder /opt/app-root/deps /opt/app-root/deps
COPY app/ /opt/app-root/src/

WORKDIR /opt/app-root/src
USER 65532
EXPOSE 8080

ENTRYPOINT ["python3", "-m", "gunicorn", "--config", "/opt/app-root/src/gunicorn.conf.py", "wsgi:app"]
