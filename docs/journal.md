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