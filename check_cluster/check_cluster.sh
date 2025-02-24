#!/bin/bash

THRESHOLD=80  # If CPU usage > 80%, migrate jobs
CURRENT_USAGE=$(sinfo -o "%C" | awk -F/ '{print $1/$2 * 100}')

if (( $(echo "$CURRENT_USAGE > $THRESHOLD" | bc -l) )); then
    echo "Resources exhausted! Migrating jobs to AWS..."
    /opt/slurm/migrate_jobs.sh
else
    echo "Cluster resources are fine. No migration needed."
fi
