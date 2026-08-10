#!/usr/bin/env bash
# Restore the shared Postgres instance from a dump made by backup-postgres.sh.
#
# This is destructive: --clean drops each object before recreating it, so the
# current contents of the target database are replaced by whatever is in the
# dump. That is why it takes an explicit path, refuses to guess which file you
# meant, and asks before doing anything. It is deliberately NOT a make target —
# a restore should never be one keystroke away from a backup.
#
# Usage:
#   ./scripts/restore-postgres.sh ~/dev-homelab-backups/homelab-20260810-120000.dump
#   ./scripts/restore-postgres.sh <file> --yes      # skip the confirmation
#
# Roles are not restored here. If a role the dump depends on is missing, load the
# matching globals file first:
#   docker exec -i postgres psql -U <user> -d postgres < globals-<stamp>.sql

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
CONTAINER="postgres"

DUMP="${1:-}"
ASSUME_YES="${2:-}"

[[ -n "$DUMP" ]] || { echo "usage: $(basename "$0") <dump-file> [--yes]" >&2; exit 1; }
[[ -f "$DUMP" ]] || { echo "no such file: $DUMP" >&2; exit 1; }
[[ -f "$ENV_FILE" ]] || { echo "no .env at $ENV_FILE" >&2; exit 1; }

env_value() { grep -E "^$1=" "$ENV_FILE" | tail -n1 | cut -d= -f2- || true; }
PG_USER="$(env_value POSTGRES_USER)"
PG_DB="$(env_value POSTGRES_DB)"

docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true \
  || { echo "container '$CONTAINER' is not running" >&2; exit 1; }

# Check the archive is readable before touching the live database.
docker exec -i "$CONTAINER" pg_restore --list > /dev/null < "$DUMP" \
  || { echo "'$DUMP' is not a readable pg_dump archive" >&2; exit 1; }

if [[ "$ASSUME_YES" != "--yes" ]]; then
  echo "About to restore into database '$PG_DB' on container '$CONTAINER'."
  echo "Existing objects in that database will be dropped and replaced."
  echo "Source: $DUMP"
  read -r -p "Type the database name to confirm: " reply
  [[ "$reply" == "$PG_DB" ]] || { echo "aborted"; exit 1; }
fi

# --clean --if-exists so a restore onto a partially populated database does not
# fail on the first object that already exists. Errors are reported but do not
# abort the run, which is why the exit status is checked explicitly below.
docker exec -i "$CONTAINER" pg_restore \
  -U "$PG_USER" -d "$PG_DB" \
  --clean --if-exists --no-owner \
  < "$DUMP"

echo "restored $PG_DB from $(basename "$DUMP")"
