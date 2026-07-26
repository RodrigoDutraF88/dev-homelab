# Architecture

## Goal

dev-homelab is a small, real self-hosted platform running on a 2019 MacBook
Air (Fedora, t2linux patches). It exists to practice DevOps concepts, reverse proxying, service discovery, observability, secrets management,
CI/CD to a self-hosted target, on infrastructure I actually run and maintain, not a tutorial sandbox.
Everything is defined as code: Compose files, Traefik config, and
provisioning scripts are committed to this repository. Nothing is clicked into existence in a UI without also being captured in a file.

## Physical host

Hardware: MacBook Air 2019 (T2 chip)
OS: Fedora Linux, patched with the t2linux project so the internal: keyboard, trackpad, audio and Wi-Fi work under Linux
Role: single-node Docker host.


## Repository layout and why

 `apps/`: Small services whose source *lives* in this repo, I'll add my recent full-stack project that i made: Bookshelf App. The main app does not live here, it's pulled from GHCR as a prebuilt image, keeping this repo focused on infrastructure, not application code.
 `infrastructure/`: Per-service configuration that isn't just a Compose block: Traefik static/dynamic config, Prometheus scrape configs, Grafana provisioning, etc.
 `compose/`: The Compose files that actually wire everything together. `docker-compose.yml` for local/dev, `production.yml` as an overlay for prod-only concerns (TLS, resource limits, pinned tags). 
 `scripts/`: Bootstrap / maintenance scripts (host provisioning, backups, cert renewal helpers). 
 `docs/`: This file, plus a running learning journal of decisions.

## Design decisions

 **Traefik over Nginx**: automatic service discovery via Docker labels
  removes the need to hand-edit proxy config every time a service is
  added or removed.
 **External application via GHCR, not a git submodule or copy**: the
  full-stack app (NestJS + Next.js + Prisma + PostgreSQL) has its own
  repository and its own CI/CD pipeline that publishes to GHCR. This repo
  only references the published image tag; 
 **Single external Docker network (`dev-homelab`)**: all services share
  one network so Traefik can reach them and they can reach each other
  (e.g. the app reaching Postgres) by service name, without publishing
  internal ports to the host.
 **No ports published except 80/443**: every other service (Postgres,
  Redis, the dashboard's raw :8080) stays internal-only and is reached
  either through Traefik or through `docker exec` / internal networking.


## Roadmap 

1. Traefik (reverse proxy + dashboard)
2. Portainer (container management UI)
3. PostgreSQL + Redis (shared data services)
4. The Bookshelf App full-stack app, pulled from GHCR, routed through Traefik
5. Uptime Kuma (uptime monitoring)
6. Prometheus (metrics collection)
7. Grafana (dashboards, fed by Prometheus)
8. TLS via Let's Encrypt, `compose/production.yml` activated
9. Backup scripts for Postgres volumes
10. Host provisioning script (`scripts/`) to rebuild the machine from scratch if needed
