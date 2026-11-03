# Build stage
FROM python:3.12-slim AS build

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir --prefix=/install -r requirements.txt

# Production stage
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY --from=build /install /usr/local
COPY src ./src

# Non-root, no shell login; the task runs with a read-only root filesystem
RUN useradd --system --no-create-home appuser
USER appuser

EXPOSE 5320

CMD ["python3", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "5320"]
