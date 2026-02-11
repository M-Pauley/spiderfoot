# joshuapfritz/spiderfoot

Containerized **SpiderFoot** OSINT scanner with a non-root runtime, sane defaults, and versioned tags.
Runs the SpiderFoot web UI on **port 5001**, persists data to **/data**, and is ready for Docker or Kubernetes.

## Features

* 🐳 Based on `python:3.12-slim`
* 👤 Runs as non-root (UID/GID **10001**)
* 💾 Persistent state at **/data** (configs, DB, scans)
* 🔒 No elevated caps; compatible with Kubernetes **Pod Security restricted**
* 🏷️ **Semantic tags** (e.g., `v4.0`) + `latest`
* 🧱 Arch: **linux/amd64**

## Tags

* `latest` – rolling
* `vX.Y` – semantic tag (e.g., `v4.0`) matching the upstream SpiderFoot release used at build time

> Note: SpiderFoot’s UI does **not** include built-in auth. Put it behind a reverse proxy (e.g., Traefik, Nginx) with auth or an access gateway (e.g., Cloudflare Access).

---

## Quick start (Docker)

```bash
docker run -d --name spiderfoot \
  -p 5001:5001 \
  -v $PWD/spiderfoot-data:/data \
  joshuapfritz/spiderfoot:v4.0
# Open http://localhost:5001
```

### docker-compose

```yaml
services:
  spiderfoot:
    image: joshuapfritz/spiderfoot:v4.0
    ports:
      - "5001:5001"
    volumes:
      - ./spiderfoot-data:/data
    restart: unless-stopped
```

---

## Kubernetes (example)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: spiderfoot-data
spec:
  accessModes: ["ReadWriteOnce"]
  resources: { requests: { storage: 5Gi } }

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spiderfoot
spec:
  replicas: 1
  selector:
    matchLabels: { app: spiderfoot }
  template:
    metadata:
      labels: { app: spiderfoot }
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile: { type: RuntimeDefault }
      containers:
        - name: spiderfoot
          image: joshuapfritz/spiderfoot:v4.0
          ports:
            - containerPort: 5001
          env:
            - name: HOME
              value: /data
          volumeMounts:
            - name: data
              mountPath: /data
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: { drop: ["ALL"] }
          readinessProbe:
            httpGet: { path: "/", port: 5001 }
            initialDelaySeconds: 10
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: spiderfoot-data

---
apiVersion: v1
kind: Service
metadata:
  name: spiderfoot
spec:
  type: ClusterIP
  ports:
    - port: 5001
      targetPort: 5001
  selector:
    app: spiderfoot
```

> With Kustomize, you can pin the tag centrally:

```yaml
# kustomization.yaml (overlay)
images:
  - name: joshuapfritz/spiderfoot
    newTag: v4.0
```

---

## Reverse proxy tips

* **No base path**: SpiderFoot serves from `/`. If exposing under a path (e.g., `/spider`), use a proxy that **strips the prefix**.
* **TLS**: terminate at your proxy or edge (e.g., Cloudflare), pass HTTP to the pod.

---

## Ports & volumes

* **5001/tcp** – web UI
* **/data** – persistent app data (mounted writable)

---

## Health checks

* Readiness: `GET /` (HTTP 200)
* Liveness: TCP `:5001`

---

## License & source

* SpiderFoot is © its respective authors. See the upstream project for license and usage details.
* This image packages the open-source SpiderFoot application for convenience.
