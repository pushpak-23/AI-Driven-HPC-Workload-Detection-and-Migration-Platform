#!/bin/bash

AWS_BUCKET="s3://slurm-checkpoints"

echo "Syncing checkpoint files from S3..."
aws s3 sync $AWS_BUCKET /checkpoint/

echo "Restarting jobs from checkpoint..."
for checkpoint in /checkpoint/*.ckpt; do
    scontrol restart $checkpoint
done
