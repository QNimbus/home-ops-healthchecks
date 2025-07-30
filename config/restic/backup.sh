#!/bin/sh
set -e

INTERVAL="${RESTIC_BACKUP_INTERVAL:-86400}"

while true; do
  echo "Restic: starting backup"
  restic backup /data
  restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 12
  echo "Restic: backup complete, sleeping for ${INTERVAL} seconds"
  sleep "$INTERVAL"
done
