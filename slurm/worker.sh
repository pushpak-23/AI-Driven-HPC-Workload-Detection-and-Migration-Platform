#!/bin/bash

# Step 1: Update and install required dependencies
sudo apt install -y build-essential munge libmunge-dev libmunge2 \
  libmysqlclient-dev libssl-dev libpam-dev libnuma-dev perl wget

# Step 2: Download and extract the Slurm tarball
wget https://download.schedmd.com/slurm/slurm-21.08.8.tar.bz2
tar -xvjf slurm-21.08.8.tar.bz2
cd slurm-21.08.8/

# Step 3: Compile and install Slurm
./configure --prefix=/home/ubuntu/slurm-21.08.8/
make
sudo make install

# Step 4: Configure Munge
# Ensure the Munge key is properly configured and permissions are set
sudo cp /tmp/munge.key /etc/munge/
sudo chown -R munge: /etc/munge /var/log/munge/
sudo chmod 0700 /etc/munge /var/log/munge/
sudo systemctl enable munge
sudo systemctl start munge

# Step 5: Configure Slurm
# Copy Slurm configuration from the controller
sudo mkdir -p /etc/slurm /etc/slurm-llnl/
sudo cp /tmp/slurm.conf /etc/slurm/
sudo cp /tmp/slurm.conf /etc/slurm-llnl/

# Step 6: Configure Slurm services
cd /home/ubuntu/slurm-21.08.8/etc/
sudo cp slurmd.service /etc/systemd/system/

# Step 7: Set up directories for Slurm daemon
sudo mkdir -p /var/spool/slurmd
sudo chown -R ubuntu:ubuntu /var/spool/slurmd/
sudo chmod 0755 /var/spool/slurmd/

# Step 8: Verify Munge and Slurm daemon statuses
sudo systemctl status munge
sudo systemctl status slurmd

# Step 9: Set environment variables for Slurm
export LD_LIBRARY_PATH="/home/ubuntu/slurm-21.08.8/lib:$LD_LIBRARY_PATH"
export PATH="/home/ubuntu/slurm-21.08.8/sbin/:$PATH"
export PATH="/home/ubuntu/slurm-21.08.8/bin/:$PATH"

# Add environment variables to ~/.bashrc for persistence
echo 'export LD_LIBRARY_PATH="/home/ubuntu/slurm-21.08.8/lib:$LD_LIBRARY_PATH"' >> ~/.bashrc
echo 'export PATH="/home/ubuntu/slurm-21.08.8/sbin/:$PATH"' >> ~/.bashrc
echo 'export PATH="/home/ubuntu/slurm-21.08.8/bin/:$PATH"' >> ~/.bashrc

# Source the updated bashrc
source ~/.bashrc

# Step 10: Enable and start Slurm daemons
sudo systemctl enable slurmd
sudo systemctl start slurmd