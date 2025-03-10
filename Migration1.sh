#!/bin/bash

# Define thresholds
CPU_THRESHOLD=90  # 90% CPU usage
MEM_THRESHOLD=90  # 90% Memory usage
AWS_BUCKET="s3://slurm-checkpoints"

# Get node name
NODE_NAME=$(hostname)

# Get resource usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'.' -f1)
MEMORY_USAGE=$(free | awk '/Mem:/ {printf("%.0f\n", $3/$2 * 100)}')

echo "Checking resources on $NODE_NAME..."
echo "CPU Usage: $CPU_USAGE%, Memory Usage: $MEMORY_USAGE%"

# If resource usage exceeds threshold, trigger checkpointing
if [[ "$CPU_USAGE" -ge "$CPU_THRESHOLD" || "$MEMORY_USAGE" -ge "$MEM_THRESHOLD" ]]; then
    echo "Resources exceeded limits! Initiating BLCR checkpointing..."

    # Get running job IDs
    JOBS=$(squeue -h -o "%A" --states=RUNNING --nodelist=$NODE_NAME)

    for JOB in $JOBS; do
        echo "Checkpointing job $JOB using BLCR..."
        cr_checkpoint --save-all -f /checkpoint/job_${JOB}.ckpt
    done

    # Sync checkpoint files to S3
    echo "Uploading checkpoints to S3..."
    aws s3 sync /checkpoint/ $AWS_BUCKET --storage-class STANDARD

    # Drain the node to prevent new jobs from running
    echo "Draining node $NODE_NAME..."
    scontrol update nodename=$NODE_NAME state=DRAIN reason="High resource usage"

else
    echo "Resources are within limits, no checkpointing needed."
fi
