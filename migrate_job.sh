#!/bin/bash

AWS_BUCKET="s3://slurm-checkpoints"

echo "Checkpointing running SLURM jobs..."
for job in $(squeue --format="%A" --state=RUNNING); do
    scontrol checkpoint create JobId=$job
done

echo "Syncing checkpoint files to S3..."
aws s3 sync /checkpoint/ $AWS_BUCKET --storage-class STANDARD
