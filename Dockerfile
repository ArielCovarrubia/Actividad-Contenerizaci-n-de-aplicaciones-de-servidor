# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.13

# BUILD STAGE ========================================================

FROM python:${PYTHON_VERSION}-slim AS build

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

WORKDIR /app

COPY pyproject.toml uv.lock ./

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# DEVELOPMENT STAGE ========================================================

FROM build AS dev

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    DB_PATH=/data/data.db

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project

COPY app ./app
COPY public ./public

RUN mkdir -p /data
VOLUME ["/data"]
EXPOSE 3000

CMD ["uvicorn", "app.main:app", "--reload", "--host", "0.0.0.0", "--port", "3000"]


# PRODUCTION STAGE ========================================================

FROM python:${PYTHON_VERSION}-slim AS prod

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DB_PATH=/data/data.db

WORKDIR /app

RUN useradd --system --create-home --uid 1000 appuser \
    && mkdir -p /data \
    && chown appuser:appuser /data

COPY --from=build --chown=appuser:appuser /app/.venv ./.venv
COPY --chown=appuser:appuser app ./app
COPY --chown=appuser:appuser public ./public

USER appuser

VOLUME ["/data"]
EXPOSE 3000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "3000"]