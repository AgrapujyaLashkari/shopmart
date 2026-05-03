#!/bin/sh
set -eu

if [ "${RUN_DB_MIGRATIONS:-true}" = "true" ]; then
  attempts=0
  max_attempts="${DB_MIGRATION_MAX_ATTEMPTS:-20}"

  until (cd /app/server && npx prisma migrate deploy); do
    attempts=$((attempts + 1))

    if [ "$attempts" -ge "$max_attempts" ]; then
      echo "Prisma migrations failed after ${attempts} attempts."
      exit 1
    fi

    echo "Database not ready yet. Retrying migrations in 5 seconds..."
    sleep 5
  done
fi

exec node /app/server/src/index.js
