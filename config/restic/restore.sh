#!/bin/sh
set -e

if restic snapshots >/dev/null 2>&1; then
  echo "Restic: restoring latest snapshot"
  restic restore latest --target /
else
  echo "Restic: no snapshots found, skipping restore"
fi
