# Learning journal

# Things i Learned

Multi-Container Orchestration: Docker Compose allows you to define dozens of different containers like traefik, postgresql, redis etc.Because they all share the same docker-compose.yml, they can easily share networks.

Container-to-Container: Containers on the same docker network can talk to each other directly using their service names.

Container-to-Host: The ports: mapping like 80:80, is for exposing a port from inside the container out to your actual physical machine so that me or external traffic can reach it from a browser.

Traefik:Traefik is an automated reverse proxy and load balancer that plugs directly into Docker to dynamically route web traffic to your containers using clean subdomains and automatic SSL certificates, eliminating the need for manual routing or port numbers.

reverse proxy: Is a intermediate server that sits in front of web servers, intercepting all requests before they reach the origin server.

Debian and Alpine: are two Linux distributions commonly used as base images for Docker containers. Debian is a complete, stable, and highly compatible distribution with a large software ecosystem, while Alpine is a lightweight and minimal distribution designed to produce very small container images.

Traefic static configurations: sets up how traefik runs, the providers are: docker , exposebydefault ensures that the containers exposed to the web are the ones that contain a especific declaration traefik.enable=true. network = dev-homelab, tells traefik to route traffic in the specific docker network named dev-homelab. logging: log sets the Traefik application log level to INFO, capturing standard operational messages, warnings, and errors. accessLog{}. enables the access log, which records every incoming HTTP request passing through Traefik.

Traefik has 
Static configurations: defines Entrypoints, providers, global settings.
Dynamic configurations(Docker labels):defines what traffic goes where on a per-service basis.

Docker-compose: brings the container itself and uses docker labels to tell traefik which services to route. Services are added to it as the homelab grows(modular growth). Services is the main section where all containers are defined.command: passes a list of command-line flags directly to the Traefik binary on startup. Ports: maps networks ports from de host machine to the container, external acces to port 8080 is blocked, so it needs to go through traefik's reverse proxy router with authentication. Volumes: mounts files or directories from the host machine into the container. Networks: connects the container to specific Docker networks. dev-homelab: attaches the traefik container to the dev-homelab network created before. 

Portainer: is a lightweight, open-source management tool that provides a graphical user interface (GUI) for managing containerized environments like Docker, Docker Swarm, and Kubernetes.

Postgres/Redis: first services with no published ports reachable
only by other containers on dev-homelab, by service name.

Redis (Remote Dictionary Server) is an open-source, in-memory data structure store used primarily as a database, cache, message broker, and streaming engine. Unlike traditional databases that store data on hard drives or SSDs (disk-based storage), Redis keeps its entire dataset in RAM, allowing for exceptionally fast read and write speeds (sub-millisecond latency). While it operates in-memory, it can also persist data to disk through snapshots or append-only logs (AOF) to ensure durability.

Secrets in version control: .gitignore only stops files that git is not already tracking. My .env was committed in the very first commit, so adding it to .gitignore later did nothing at all: git kept tracking it because it was already in the index. The fix is `git rm --cached .env`, which removes the file from git's index while leaving it on disk. From that point on the gitignore rule finally applies.

Untracking is only half the job though. Every old commit still contains the file, so anyone who clones the repo can read the secrets out of the history. That means the secrets have to be treated as burned and rotated, i.e. replaced with new values, not just hidden.

Rotating a database password is not the same as editing .env. POSTGRES_PASSWORD is only read once, the very first time the container initialises an empty data directory. After that the password lives inside the postgres volume, so changing the variable and restarting does nothing. The real rotation is an SQL statement against the running database (ALTER USER ... WITH PASSWORD ...), and .env is updated to match. Redis is the opposite: its password comes from the --requirepass command flag, which is re-read on every start, so there a restart is genuinely enough. Same for Traefik's basic-auth hash, which is just a label.

Compose reads .env values through variable interpolation, so a literal dollar sign has to be written as $$. This matters for the bcrypt hash from htpasswd, which is full of them ($2y$05$...). Written with single dollars, Compose treats $2y and $05 as variable references, substitutes them with empty strings, and stores a truncated hash, which silently locks you out of the dashboard rather than throwing an error.

A rotation is only real if the old credential actually stops working. Worth testing both directions: the new password succeeds and the old one is refused. Testing only the new one would not have caught a postgres password that was never really changed.