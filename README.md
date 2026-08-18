# 💻🐳 dev-homelab

[English](#english), [Português](#português), [Italiano](#italiano)

A self-hosted homelab running on a 2019 MacBook Air (Fedora + [t2linux](https://wiki.t2linux.org/)), defined entirely as Infrastructure as Code.


## English

### What it is
A single-node Docker host where every service is reproducible from this repo alone: Traefik, Portainer, Postgres, Redis, a full-stack app pulled from GHCR, Uptime Kuma, Prometheus, Grafana and Alertmanager.

### Layout
- `compose/` — Compose files (dev + production overlay)
- `infrastructure/` — Traefik, Prometheus, Grafana, Alertmanager, systemd units
- `scripts/` — backup, restore, certs, provisioning
- `docs/` — [architecture](docs/architecture.md) and [learning journal](docs/journal.md)

### What I learned
- **Reverse proxying** — Traefik routes by Docker labels, so adding a service needs no proxy edits. Static config defines entrypoints; dynamic config is per-service.
- **Networking** — containers talk by service name on a shared network; only 80/443 are published to the host.
- **TLS** — Traefik terminates HTTPS; Let's Encrypt issues via ACME, DNS-01 being the only path to wildcards. A self-signed cert encrypts but vouches for nobody.
- **Secrets** — `.gitignore` does nothing for already-tracked files. A leaked secret must be rotated, not hidden, and rewriting history is cleanup, not a fix.
- **Databases** — sharing a server is not sharing a database: the app gets its own role and schema. Migrations run in a one-shot container, never at app startup.
- **Backups** — ask the server for its database list instead of hardcoding one, and verify by actually restoring; `--no-owner` produces a database the app cannot read.
- **Observability** — exporters translate state into metrics; blackbox probes check from outside, twice (internally and through the proxy), because a broken app and a broken path are different outages.
- **Alerting** — Prometheus evaluates rules, Alertmanager decides what happens. `for:` clauses avoid false alarms, and a permanent Watchdog covers Prometheus's own death.
- **Scheduling** — systemd timers over cron: they live in the repo and catch up after a suspend.

---

## Português

### O que é
Um host Docker de nó único onde cada serviço é reprodutível apenas a partir deste repositório: Traefik, Portainer, Postgres, Redis, uma aplicação full-stack vinda do GHCR, Uptime Kuma, Prometheus, Grafana e Alertmanager.

### Estrutura
- `compose/` — ficheiros Compose (dev + overlay de produção)
- `infrastructure/` — Traefik, Prometheus, Grafana, Alertmanager, units systemd
- `scripts/` — backup, restauro, certificados, provisionamento
- `docs/` — [arquitetura](docs/architecture.md) e [diário de aprendizagem](docs/journal.md)

### O que aprendi
- **Proxy reverso** — o Traefik encaminha por labels do Docker, logo adicionar um serviço não exige editar o proxy. A config estática define entrypoints; a dinâmica é por serviço.
- **Rede** — os contentores comunicam pelo nome do serviço numa rede partilhada; só 80/443 são expostos ao host.
- **TLS** — o Traefik termina o HTTPS; o Let's Encrypt emite via ACME, sendo o DNS-01 o único caminho para wildcards. Um certificado self-signed encripta mas não garante identidade.
- **Segredos** — o `.gitignore` não afeta ficheiros já versionados. Um segredo exposto tem de ser rodado, não escondido; reescrever o histórico é limpeza, não solução.
- **Bases de dados** — partilhar um servidor não é partilhar uma base de dados: a app tem o seu próprio role e schema. As migrações correm num contentor one-shot, nunca no arranque da app.
- **Backups** — perguntar ao servidor que bases existem em vez de as fixar no script, e verificar restaurando de facto; `--no-owner` gera uma base que a app não consegue ler.
- **Observabilidade** — os exporters traduzem estado em métricas; as sondas blackbox testam de fora, duas vezes (internamente e via proxy), porque uma app em baixo e um caminho em baixo são falhas diferentes.
- **Alertas** — o Prometheus avalia regras, o Alertmanager decide o que acontece. As cláusulas `for:` evitam falsos alarmes e um Watchdog permanente cobre a morte do próprio Prometheus.
- **Agendamento** — timers systemd em vez de cron: vivem no repositório e recuperam execuções após suspensão.

---

## Italiano

### Cos'è
Un host Docker a nodo singolo dove ogni servizio è riproducibile solo a partire da questo repository: Traefik, Portainer, Postgres, Redis, un'applicazione full-stack presa da GHCR, Uptime Kuma, Prometheus, Grafana e Alertmanager.

### Struttura
- `compose/` — file Compose (dev + overlay di produzione)
- `infrastructure/` — Traefik, Prometheus, Grafana, Alertmanager, unit systemd
- `scripts/` — backup, ripristino, certificati, provisioning
- `docs/` — [architettura](docs/architecture.md) e [diario di apprendimento](docs/journal.md)

### Cosa ho imparato
- **Reverse proxy** — Traefik instrada tramite label Docker, quindi aggiungere un servizio non richiede modifiche al proxy. La configurazione statica definisce gli entrypoint, quella dinamica è per servizio.
- **Rete** — i container si parlano per nome di servizio su una rete condivisa; solo 80/443 sono esposti all'host.
- **TLS** — Traefik termina l'HTTPS; Let's Encrypt emette via ACME, e DNS-01 è l'unica via per i wildcard. Un certificato self-signed cifra ma non garantisce l'identità.
- **Segreti** — `.gitignore` non serve per file già tracciati. Un segreto esposto va ruotato, non nascosto; riscrivere la storia è pulizia, non una soluzione.
- **Database** — condividere un server non è condividere un database: l'app ha il proprio ruolo e schema. Le migrazioni girano in un container one-shot, mai all'avvio dell'app.
- **Backup** — chiedere al server l'elenco dei database invece di fissarlo nello script, e verificare ripristinando davvero; `--no-owner` produce un database che l'app non riesce a leggere.
- **Osservabilità** — gli exporter traducono lo stato in metriche; le sonde blackbox controllano dall'esterno, due volte (internamente e tramite proxy), perché un'app rotta e un percorso rotto sono guasti diversi.
- **Allerte** — Prometheus valuta le regole, Alertmanager decide cosa fare. Le clausole `for:` evitano falsi allarmi e un Watchdog permanente copre la morte di Prometheus stesso.
- **Pianificazione** — timer systemd invece di cron: vivono nel repository e recuperano le esecuzioni dopo una sospensione.

---

## License

MIT
