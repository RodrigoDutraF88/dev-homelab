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

Rewriting history: untracking a file only cleans the latest commit. To remove it from every commit, the history itself has to be rebuilt, with `git filter-repo --path .env --invert-paths`. This walks all 13 commits, rewrites each one without that file, and repacks the repository. Because a commit's identity is a hash of its content, removing a file changes every commit ID from the first affected commit onward. The old and new histories share no commits at all, which is why the remote will not accept a normal push and needs `--force`.

Two side effects worth knowing about. The commit whose only change was deleting `.env` became an empty commit once `.env` no longer existed anywhere, so filter-repo dropped it: 13 commits became 12. And filter-repo rebuilds the working directory from the new history, which deleted my on-disk `.env` even though it was untracked and gitignored. It holds the live passwords for the running stack, so losing it would have meant regenerating everything. Taking a full copy of the folder before running a destructive command is what made that a non-event rather than an outage.

Force pushing is not a complete fix, only a cleanup of the public record. Anyone who cloned or forked the repo before the rewrite still has the old commits on their machine, and GitHub may keep the old objects reachable for a while. Rotating the passwords is the part that actually protects the stack. The rewrite just stops the old values being handed to the next person who clones. But since my project was private, it's safe to say that nothing leaked.

uptime-kuma: Uptime Kuma is a self hosting monitoring tool
What are the differences between traefik, pontainer and uptime kuma? Traefik gets traffic to your services, Portainer lets you manage the containers behind those services, Uptime Kuma watches whether those services are actually responding.

Prometheus & Grafana: 
Prometheus: is a metrics collection, time-series database, and alerting system.It features a query language called PromQL (Prometheus Query Language) that allows developers to filter, aggregate, and compute rates of change across metrics. 
Grafana: is a data visualization, dashboarding and exploration platform. Grafana queries backends like Prometheus and renders the data into costumized graphs, heatmaps, gauges, status maps, and tables.
How they work together: My server exposes a route, prometheus scrapes that route, stores the time-series points, and monitors for alert conditions. Grafana connects to prometheus, runs PromQL queries in the background and displays real-time health graphs on a dashboard.

Http vs Https: HTTP sends every request and response as clear text, so anyone sitting between the browser and the server (the wifi you are on, any router along the way) can read it and even change it. HTTPS is the same HTTP, only wrapped in a TLS layer that encrypts the traffic and proves the server really is the one it claims to be. Everything in this homelab was plain HTTP until roadmap step 8, which meant the Traefik dashboard password and the Grafana login were travelling in the open. On a laptop talking to itself that is not dramatic, but it stops being acceptable the moment the stack is reachable from anywhere else.

Certificate Authority: encrypting is not enough on its own, because you could be encrypting your traffic straight into the hands of an impostor. A certificate authority is a third party that both sides already trust: it checks that whoever asks for a certificate actually controls the domain, and then signs that certificate with its own key. Browsers and operating systems ship with a built-in list of CAs they trust, so anything signed by one of them is accepted without a word. The certificate I generated with openssl for *.localhost is signed by nothing but itself, the issuer and the subject are the same line, and that is exactly why the browser complains: the encryption is real, but nobody is vouching for who I am. It is also why no CA could help here even if I asked, since localhost is a name that belongs to everybody and control of it cannot be proven.

TLS: TLS (Transport Layer Security, the successor of SSL) is the layer that turns HTTP into HTTPS. At the start of a connection the client and the server do a handshake: the server presents its certificate, the client checks who signed it and whether the name matches the site it asked for, and the two agree on a session key that encrypts the rest of the conversation. In this stack Traefik is where TLS is terminated, meaning the browser speaks HTTPS to Traefik and Traefik speaks ordinary HTTP to the containers behind it over the dev-homelab network. That second hop never leaves the machine, so it is fine, and it means no individual service has to know anything about certificates. One thing that caught me out: a router marked tls=true only answers TLS connections, so leaving it listening on port 80 as well achieves nothing, plain requests simply stop matching and come back as 404. The fix is to redirect at the entrypoint instead, so :80 answers everything with a 301 to :443.

Let's Encrypt: a free, automated certificate authority. Instead of buying a certificate and installing it by hand, the server proves it controls the domain over a protocol called ACME and gets a certificate back in seconds, valid for 90 days and renewed automatically. The proof is a challenge: with HTTP-01 the CA connects back to the domain on port 80 and looks for a file only the real owner could have put there, and with DNS-01 you publish a TXT record in the zone instead, which still works when nothing is reachable from outside and is the only way to get a wildcard certificate. Both need a real registered domain, so none of it works on localhost, which is why the ACME configuration sits in compose/production.yml waiting for the day I have one. Traefik keeps whatever it is issued in an acme.json inside its own volume and handles the renewals on its own. Worth aiming at the staging server first, because the real one allows only 5 failed validations per hour and 50 certificates per domain per week, and those are easy to burn through while a config is still wrong.
