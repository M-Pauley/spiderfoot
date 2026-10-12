# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim AS builder

ARG SPIDERFOOT_REF=master

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    libffi-dev \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/spiderfoot

RUN git clone https://github.com/smicallef/spiderfoot.git . \
    && git checkout "$SPIDERFOOT_REF" \
    && git rev-parse HEAD > /tmp/UPSTREAM_COMMIT \
    && rm -rf .git

# Update to newer build requirement versions to minimize potential CVEs
COPY requirements-overrides.txt /tmp/requirements-overrides.txt

RUN python - <<'PY'
from pathlib import Path

requirements = Path("/opt/spiderfoot/requirements.txt")
overrides = Path("/tmp/requirements-overrides.txt")

replacements = {
    line.split(">=")[0].lower(): line.strip()
    for line in overrides.read_text().splitlines()
    if line.strip() and not line.startswith("#")
}

lines = requirements.read_text().splitlines()

for i, line in enumerate(lines):
    package = line.split(">=")[0].lower()
    if package in replacements:
        lines[i] = replacements[package]

requirements.write_text("\n".join(lines) + "\n")
PY

RUN python -m pip wheel \
    --wheel-dir /wheels \
    -r requirements.txt

# --------------------------------------------------
# Runtime
# --------------------------------------------------
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/data \
    SPIDERFOOT_DIR=/opt/spiderfoot

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libffi8 \
    libssl3t64 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /wheels /tmp/wheels
COPY --from=builder /opt/spiderfoot /opt/spiderfoot
COPY --from=builder /tmp/UPSTREAM_COMMIT /UPSTREAM_COMMIT

WORKDIR /opt/spiderfoot

RUN python -m pip install \
      --no-index \
      --find-links=/tmp/wheels \
      -r requirements.txt \
    && rm -rf /tmp/wheels \
    && groupadd -g 10001 appuser \
    && useradd -u 10001 -g 10001 \
         -d /data -s /usr/sbin/nologin appuser \
    && mkdir -p /data \
    && chown 10001:10001 /data

LABEL org.opencontainers.image.title="SpiderFoot" \
      org.opencontainers.image.description="Hardened SpiderFoot 4.0 container" \
      org.opencontainers.image.source="https://github.com/joshuapfritz/spiderfoot" \
      org.opencontainers.image.url="https://hub.docker.com/r/joshuapfritz/spiderfoot" \
      org.opencontainers.image.vendor="Joshua P. Fritz"

USER 10001:10001

VOLUME ["/data"]
EXPOSE 5001

CMD ["python3", "sf.py", "-l", "0.0.0.0:5001"]
