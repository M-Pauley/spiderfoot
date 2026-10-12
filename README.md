# SpiderFoot — Hardened Container

[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-joshuapfritz%2Fspiderfoot-blue?logo=docker)](https://hub.docker.com/r/joshuapfritz/spiderfoot)
[![Upstream](https://img.shields.io/badge/Upstream-SpiderFoot-555)](https://github.com/smicallef/spiderfoot)

A maintained container build of **SpiderFoot 4.0**, the open-source OSINT reconnaissance platform. This repository focuses on **container security and dependency updates**, not modifications to SpiderFoot's application modules.

- **Multi-stage build:** compilers, Git, and build dependencies stay out of the runtime image.
- **Non-root runtime:** UID/GID `10001:10001`; listens on TCP `5001`.
- **Persistent data:** writable `/data` volume (`HOME=/data`).
- **Hardened deployment:** compatible with Kubernetes restricted security settings when configured as shown below.
- **Modernized Python dependencies:** selected upstream version constraints are overridden during the build.

## Images

| Tag | Purpose |
| --- | --- |
| [`v4.0-update`](https://hub.docker.com/r/joshuapfritz/spiderfoot/tags) | SpiderFoot 4.0 container-maintenance release |
| [`latest`](https://hub.docker.com/r/joshuapfritz/spiderfoot/tags) | Current published image |

The `v4.0-update` tag describes **this image**, not a new SpiderFoot upstream release. The image has been tested on `linux/amd64`.

## Run with Docker

```bash
mkdir -p spiderfoot-data
sudo chown 10001:10001 spiderfoot-data

docker run -d --name spiderfoot \
  -p 127.0.0.1:5001:5001 \
  -v "$PWD/spiderfoot-data:/data" \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  --restart unless-stopped \
  joshuapfritz/spiderfoot:v4.0-update
```

Open <http://localhost:5001>. The localhost binding avoids exposing an unauthenticated UI to the network.

A [`docker-compose.yaml`](docker-compose.yaml) example is also provided. **Note:** update its image tag to `v4.0-update` and consider binding the published port to `127.0.0.1` before using it; the existing Compose file still references `v4.0` and publishes on all interfaces.

## Kubernetes

Manifests and Kustomize configuration are in [`k8s/`](k8s/). They include a Deployment, Service, PVC, security-context patch, and Traefik IngressRoute.

**Before deploying the current manifests:**

- Update the image tag in `k8s/kustomization.yaml` from `v4.0` to `v4.0-update`.
- Check the namespace: the resources use `devsec`, while `namespace.yaml` defines `spider`.
- Ensure the security-context patch is applied; it sets non-root execution, `RuntimeDefault` seccomp, `allowPrivilegeEscalation: false`, and drops all capabilities.
- Confirm `/data` is the active persistent mount. The base Deployment still references `/root/.spiderfoot`; the patch changes the mount to `/data`.
- Review the PVC storage class (`microk8s-hostpath`) and the Traefik hostname/path (`m.screaming-fist.com/spider`) for your environment. Prefix routing may require application-specific testing.
- Put authentication in front of the UI before exposing it externally.

These manifests reflect the original cluster deployment and are **examples**, not a portable one-command install.

## Build locally

```bash
docker build \
  --build-arg SPIDERFOOT_REF=master \
  -t spiderfoot:local .
```

`SPIDERFOOT_REF` accepts an upstream Git branch, tag, or commit. **For reproducible releases, use a specific commit SHA** rather than the moving `master` branch. The build records the resolved upstream commit in `/UPSTREAM_COMMIT` inside the image.

The build reads upstream `requirements.txt` and replaces only the package constraints listed in [`requirements-overrides.txt`](requirements-overrides.txt):

| Package | Override constraint |
| --- | --- |
| `cryptography` | `>=50,<51` |
| `pyOpenSSL` | `>=26,<27` |
| `lxml` | `>=6,<7` |

These are **version ranges**, so a later rebuild can resolve newer patch releases. The tested image included `cryptography 50.0.2`, `pyOpenSSL 26.4.0`, and `lxml 6.1.3`.

## Security and compatibility

The image runs as an unprivileged user, but **Docker itself does not automatically drop capabilities or enable `no-new-privileges`**; use the run flags above or equivalent Compose/Kubernetes settings.

SpiderFoot supports password-file authentication, but **authentication is disabled if no passwords are configured**. Use its authentication configuration or an authenticated reverse proxy/access gateway (for example, Traefik with Authentik or Cloudflare Access). Terminate TLS at the ingress or proxy.

The tested build started, served the web UI, and executed scan requests. Some upstream SpiderFoot modules can fail because external websites, APIs, or data formats change; this repository does **not** patch those modules.

A Trivy scan with `--severity CRITICAL,HIGH --ignore-unfixed` reported **zero findings** for the tested dependency-updated image. This filter excludes vulnerabilities without available fixes; an earlier unfiltered scan reported Debian OS findings. **Zero filtered findings do not mean zero risk.**

## Project scope and attribution

- **Container source and deployment examples:** this repository
- **Docker image:** <https://hub.docker.com/r/joshuapfritz/spiderfoot>
- **Upstream application:** <https://github.com/smicallef/spiderfoot>

This is an independently maintained container packaging of SpiderFoot, **not an official upstream release or an application fork**. SpiderFoot and its licensing remain with the upstream authors; see the upstream repository for licensing and attribution.
