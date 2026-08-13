#!/usr/bin/env bash
# Back up the shared Postgres instance.
#
# Every database is dumped, not just POSTGRES_DB. The instance is shared — the
# Bookshelf app has its own `bookshelf` database alongside `homelab`, and any
# future app will do the same. This script therefore asks Postgres which
# databases exist rather than being told, so a new one is protected the moment it
# is created instead of the day someone remembers to edit this file. That gap was
# real: `bookshelf` existed and went unbacked-up until 2026-08-13.
#
# One file per database, plus one for the globals, because a dump of a database
# alone is not enough to rebuild it: roles live outside any single database, so
# restoring a dump whose owner does not exist fails.
#
#   <db>-<timestamp>.dump        pg_dump custom format, compressed, restored with pg_restore
#   globals-<timestamp>.sql      roles and their passwords, restored with psql
#
# Credentials are not needed: the dump runs inside the container over the local
# unix socket, which the official image trusts. Nothing reads POSTGRES_PASSWORD,
# so no secret is ever passed on a command line where `ps` could see it.
#
# Values are read out of .env with grep rather than by sourcing it. Sourcing
# would make the shell evaluate the bcrypt hash in TRAEFIK_DASHBOARD_AUTH — the
# `$$` in it expands to the shell's PID.
#
# Usage:  make backup      or      ./scripts/backup-postgres.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
CONTAINER="postgres"

[[ -f "$ENV_FILE" ]] || { echo "no .env at $ENV_FILE" >&2; exit 1; }

# `|| true` because a key that is simply absent is not an error here: BACKUP_DIR
# and RETENTION_DAYS are optional and fall back to defaults below. Without it,
# grep's exit 1 becomes the assignment's status and set -e kills the script.
env_value() { grep -E "^$1=" "$ENV_FILE" | tail -n1 | cut -d= -f2- || true; }

PG_USER="$(env_value POSTGRES_USER)"
# Backups default to outside the repo on purpose: a destructive git operation
# rebuilds the working tree and would take them with it.
BACKUP_DIR="${BACKUP_DIR:-$(env_value BACKUP_DIR)}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/dev-homelab-backups}"
RETENTION_DAYS="${RETENTION_DAYS:-$(env_value RETENTION_DAYS)}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

[[ -n "$PG_USER" ]] || { echo "POSTGRES_USER missing from .env" >&2; exit 1; }

docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true \
  || { echo "container '$CONTAINER' is not running — start the stack with 'make up'" >&2; exit 1; }

# Ask the server what to dump. Templates are excluded because they cannot be
# connected to, and datallowconn filters anything else marked unconnectable.
mapfile -t DATABASES < <(docker exec "$CONTAINER" psql -U "$PG_USER" -d postgres -At \
  -c "select datname from pg_database where datallowconn and not datistemplate order by datname")

[[ ${#DATABASES[@]} -gt 0 ]] || { echo "no databases returned by postgres" >&2; exit 1; }

mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
GLOBALS="$BACKUP_DIR/globals-$STAMP.sql"

# Write to temporary names and rename only on success. A backup interrupted
# halfway through must not be left sitting in the directory looking valid. The
# array is cleaned as a whole, so a failure on the third database does not leave
# the first two as .partial litter.
PARTIALS=()
cleanup() { [[ ${#PARTIALS[@]} -gt 0 ]] && rm -f -- "${PARTIALS[@]}"; }
trap cleanup EXIT

for db in "${DATABASES[@]}"; do
  dump="$BACKUP_DIR/$db-$STAMP.dump"
  tmp="$dump.partial"
  PARTIALS+=("$tmp")

  docker exec "$CONTAINER" pg_dump -U "$PG_USER" -d "$db" --format=custom > "$tmp"

  # Prove the dump is readable before calling it a backup. pg_restore --list
  # parses the archive's table of contents, so a truncated or corrupt file fails
  # here rather than on the day it is needed.
  docker exec -i "$CONTAINER" pg_restore --list > /dev/null < "$tmp" \
    || { echo "dump of '$db' failed verification — not keeping it" >&2; exit 1; }

  mv "$tmp" "$dump"
  echo "$(basename "$dump")     $(du -h "$dump" | cut -f1)"
done

tmp_globals="$GLOBALS.partial"
PARTIALS+=("$tmp_globals")
docker exec "$CONTAINER" pg_dumpall -U "$PG_USER" --globals-only > "$tmp_globals"
mv "$tmp_globals" "$GLOBALS"
echo "$(basename "$GLOBALS")  $(du -h "$GLOBALS" | cut -f1)"

PARTIALS=()
trap - EXIT

# Prune old runs, but never the newest file: if the backup job silently stopped
# running weeks ago, a stale backup still beats no backup at all. Pruning is done
# per database so that one database's history cannot be shortened by another's.
prune() {
  local pattern="$1" i
  local files=()
  while IFS= read -r line; do files+=("${line#* }"); done \
    < <(find "$BACKUP_DIR" -maxdepth 1 -name "$pattern" -printf '%T@ %p\n' | sort -rn)
  for ((i = 1; i < ${#files[@]}; i++)); do
    if find "${files[i]}" -mtime +"$RETENTION_DAYS" -print -quit | grep -q .; then
      rm -f -- "${files[i]}"
      echo "pruned $(basename "${files[i]}")"
    fi
  done
}

for db in "${DATABASES[@]}"; do
  prune "$db-*.dump"
done
prune "globals-*.sql"

# Dumps of a database that no longer exists are deliberately left alone: they are
# not matched by any pattern above, and a dropped database is exactly the case
# where an old backup is most likely to be wanted.

echo "backed up ${#DATABASES[@]} databases (${DATABASES[*]}) to $BACKUP_DIR, keeping $RETENTION_DAYS days"
