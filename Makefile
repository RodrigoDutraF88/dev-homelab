# Canonical entrypoint for the homelab stack.
#
# The compose file lives in compose/, so Docker Compose would look for .env
# there and silently resolve every variable to an empty string. --env-file
# points it back at the .env in this directory. Always drive the stack through
# these targets rather than calling docker compose by hand.
#
# The project name is intentionally left at its default ("compose", taken from
# the compose file's directory) — the existing volumes are named compose_*, and
# adding -p would orphan them.

COMPOSE = docker compose --env-file .env -f compose/docker-compose.yml

.PHONY: up down restart logs ps config pull

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart: down up

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

# Render the fully resolved config. Should print no "variable is not set" warnings.
config:
	$(COMPOSE) config

pull:
	$(COMPOSE) pull
