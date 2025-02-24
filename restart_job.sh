#!/bin/bash

echo "Restarting jobs from checkpoint..."
for checkpoint in /checkpoint/*.ckpt; do
    scontrol restart $checkpoint
done
