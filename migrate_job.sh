#!/bin/bash

echo "Checkpointing running SLURM jobs..."
for job in $(squeue --format="%A" --state=RUNNING); do
    scontrol checkpoint create JobId=$job
done

echo "Transferring checkpoint files to AWS..."
scp -r /checkpoint/ ec2-user@aws-slurm-master:/checkpoint/

echo "Resuming jobs on AWS cluster..."
ssh ec2-user@aws-slurm-master "sbatch /checkpoint/restart_jobs.sh"
