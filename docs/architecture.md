# Architecture

## Goal

`dev-homelab` is a small, real self-hosted platform running on a 2019 MacBook
Air (Fedora, t2linux patches). It exists to practice DevOps concepts —
reverse proxying, service discovery, observability, secrets management,
CI/CD to a self-hosted target — on infrastructure I actually run and
maintain, not a tutorial sandbox.

Everything is defined as code: Compose files, Traefik config, and
provisioning scripts are committed to this repository. Nothing is
clicked into existence in a UI without also being captured in a file.

## Physical host

- Hardware: MacBook Air 2019 (T2 chip)
- OS: Fedora Linux, patched with the t2linux project so the internal
  keyboard, trackpad, audio and Wi-Fi work under Linux
- Role: single-node Docker host. Not HA — that's a deliberate scope
  decision (see "Non-goals" below)

## Logical architecture

```
                        Internet / LAN
                              |
                              v
                     +------------------+
                     |     Traefik      |  <- entrypoints :80 / :443
                     |  (reverse proxy) |     dashboard behind basic auth
                     +--------+---------+
                              |
        +---------------------------------------------+
        |            docker network: dev-homelab       |
        |                                               |
   +----v----+   +-----------+   +-----------+   +------v-----+
   | app-x   |   | portainer |   |uptime-kuma|   | grafana +  |
   | (GHCR)  |   |           |   |           |   | prometheus |
   +----+----+   +-----------+   +-----------+   +------------+
        |
   +----v----+   +---------+
   |postgres |   |  redis  |
   +---------+   +---------+
```

Every service that needs to be reachable from outside the Docker network
declares itself to Traefik via labels (`traefik.enable=true` +
`traefik.http.routers.<name>.rule=Host(...)`). Traefik discovers them
through the Docker provider — no manual reverse-proxy config per service.

## Repository layout and why

| Folder            | Purpose                                                                 |
|--------------------|--------------------------------------------------------------------------|
| `apps/`            | Small services whose source *lives* in this repo (e.g. a portfolio site). The main full-stack app does **not** live here — it's pulled from GHCR as a prebuilt image, keeping this repo focused on infrastructure, not application code. |
| `infrastructure/`  | Per-service configuration that isn't just a Compose block: Traefik static/dynamic config, Prometheus scrape configs, Grafana provisioning, etc. |
| `compose/`         | The Compose files that actually wire everything together. `docker-compose.yml` for local/dev, `production.yml` as an overlay for prod-only concerns (TLS, resource limits, pinned tags). |
| `scripts/`         | Bootstrap / maintenance scripts (host provisioning, backups, cert renewal helpers). |
| `docs/`            | This file, plus a running learning journal of decisions and trade-offs. |

## Design decisions

- **Traefik over Nginx**: automatic service discovery via Docker labels
  removes the need to hand-edit proxy config every time a service is
  added or removed — the label lives next to the service it routes to.
- **External application via GHCR, not a git submodule or copy**: the
  full-stack app (NestJS + Next.js + Prisma + PostgreSQL) has its own
  repository and its own CI/CD pipeline that publishes to GHCR. This repo
  only references the published image tag. That keeps concerns separated:
  application code changes trigger the app's pipeline; infrastructure
  changes are versioned here.
- **Single external Docker network (`dev-homelab`)**: all services share
  one network so Traefik can reach them and they can reach each other
  (e.g. the app reaching Postgres) by service name, without publishing
  internal ports to the host.
- **No ports published except 80/443**: every other service (Postgres,
  Redis, the dashboard's raw :8080) stays internal-only and is reached
  either through Traefik or through `docker exec` / internal networking.

## Non-goals (for now)

- High availability / multi-node clustering (Swarm or k8s) — this is a
  single physical host.
- Public internet exposure without VPN — early milestones assume access
  via local network or a VPN (documented in the roadmap in `docs/`).

## Roadmap (also reflected in commit history — see README)

1. Traefik (reverse proxy + dashboard)
2. Portainer (container management UI)
3. PostgreSQL + Redis (shared data services)
4. The full-stack app, pulled from GHCR, routed through Traefik
5. Uptime Kuma (uptime monitoring)
6. Prometheus (metrics collection)
7. Grafana (dashboards, fed by Prometheus)
8. TLS via Let's Encrypt, `compose/production.yml` activated
9. Backup scripts for Postgres volumes
10. Host provisioning script (`scripts/`) to rebuild the machine from
    scratch if needed
