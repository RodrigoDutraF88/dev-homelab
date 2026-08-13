#!/usr/bin/env bash
# Restore the shared Postgres instance from a dump made by backup-postgres.sh.
#
# This is destructive: --clean drops each object before recreating it, so the
# current contents of the target database are replaced by whatever is in the
# dump. That is why it takes an explicit path, refuses to guess which file you
# meant, and asks before doing anything. It is deliberately NOT a make target —
# a restore should never be one keystroke away from a backup.
#
# The target database is taken from the dump's filename, which backup-postgres.sh
# writes as <db>-<timestamp>.dump. This matters now that every database is backed
# up rather than only POSTGRES_DB: with the target hardcoded, restoring
# bookshelf-*.dump would have loaded the app's tables straight into `homelab`.
# Pass the database explicitly to override the guess.
#
# Usage:
#   ./scripts/restore-postgres.sh ~/dev-homelab-backups/homelab-20260810-120000.dump
#   ./scripts/restore-postgres.sh <file> --yes           # skip the confirmation
#   ./scripts/restore-postgres.sh <file> --db <name>     # override the target
#
# Roles are not restored here. If a role the dump depends on is missing, load the
# matching globals file first:
#   docker exec -i postgres psql -U <user> -d postgres < globals-<stamp>.sql

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
CONTAINER="postgres"

DUMP="${1:-}"
shift || true

ASSUME_YES=""
TARGET_DB=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) ASSUME_YES="--yes"; shift ;;
    --db)  TARGET_DB="${2:-}"; [[ -n "$TARGET_DB" ]] || { echo "--db needs a value" >&2; exit 1; }; shift 2 ;;
    *)     echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$DUMP" ]] || { echo "usage: $(basename "$0") <dump-file> [--yes] [--db <name>]" >&2; exit 1; }
[[ -f "$DUMP" ]] || { echo "no such file: $DUMP" >&2; exit 1; }
[[ -f "$ENV_FILE" ]] || { echo "no .env at $ENV_FILE" >&2; exit 1; }

env_value() { grep -E "^$1=" "$ENV_FILE" | tail -n1 | cut -d= -f2- || true; }
PG_USER="$(env_value POSTGRES_USER)"

# <db>-<timestamp>.dump — strip the trailing -YYYYmmdd-HHMMSS.dump written by
# backup-postgres.sh. A file that does not match that shape leaves PG_DB empty
# and the script stops rather than guessing at a destructive operation.
if [[ -z "$TARGET_DB" ]]; then
  TARGET_DB="$(basename "$DUMP")"
  TARGET_DB="${TARGET_DB%-[0-9]*-[0-9]*.dump}"
  [[ "$TARGET_DB" != "$(basename "$DUMP")" ]] || {
    echo "cannot tell which database '$(basename "$DUMP")' belongs to." >&2
    echo "expected <db>-<timestamp>.dump — pass it explicitly with --db <name>." >&2
    exit 1
  }
fi
PG_DB="$TARGET_DB"

docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true \
  || { echo "container '$CONTAINER' is not running" >&2; exit 1; }

# Check the archive is readable before touching the live database.
docker exec -i "$CONTAINER" pg_restore --list > /dev/null < "$DUMP" \
  || { echo "'$DUMP' is not a readable pg_dump archive" >&2; exit 1; }

# A typo in --db, or a dump whose database was since dropped, would otherwise
# only surface as pg_restore errors after the confirmation has been given.
docker exec "$CONTAINER" psql -U "$PG_USER" -d postgres -At \
  -c "select 1 from pg_database where datname = '$PG_DB'" | grep -q 1 \
  || { echo "database '$PG_DB' does not exist on '$CONTAINER' — create it first" >&2; exit 1; }

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
#
# Ownership is deliberately preserved (no --no-owner). This used to be there and
# was actively harmful once the instance stopped holding a single database: it
# reassigns every object to the restoring superuser, so a restored `bookshelf`
# database ended up owned by `homelab` and the app's own role got
# "permission denied for table Book" against its own data. Verified, not assumed.
# The roles a dump refers to must therefore exist first — that is what the
# globals file in the header note is for.
docker exec -i "$CONTAINER" pg_restore \
  -U "$PG_USER" -d "$PG_DB" \
  --clean --if-exists \
  < "$DUMP"

echo "restored $PG_DB from $(basename "$DUMP")"
