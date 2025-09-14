FROM python:3.12-slim
ENV DEBIAN_FRONTEND=noninteractive PIP_NO_CACHE_DIR=1 HOME=/data SPIDERFOOT_DIR=/opt/spiderfoot

RUN apt-get update && apt-get install -y --no-install-recommends \
      git ca-certificates libffi-dev libssl-dev build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -u 10001 -m appuser && mkdir -p /data && chown -R appuser:appuser /data
RUN git clone --depth 1 https://github.com/smicallef/spiderfoot.git "$SPIDERFOOT_DIR"
WORKDIR $SPIDERFOOT_DIR

# record the exact upstream commit we built from
RUN git rev-parse HEAD > /UPSTREAM_COMMIT

RUN pip install --upgrade pip && pip install -r requirements.txt

LABEL org.opencontainers.image.title="SpiderFoot" \
      org.opencontainers.image.source="https://github.com/smicallef/spiderfoot"

USER 10001:10001
VOLUME ["/data"]
EXPOSE 5001
CMD ["python3", "sf.py", "-l", "0.0.0.0:5001"]
