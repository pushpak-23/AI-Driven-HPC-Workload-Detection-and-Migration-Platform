#!/bin/bash

# Define variables
username=ubuntu
# c_user="ubuntu"
m_ip=$(hostname -I | awk '{print $1}')
# c_ip="192.168.82.223"
m_host="controller"
c_host1="worker1"
c_host2="worker2"
# Step 1: Download and extract Slurm source
sudo apt update
wget https://download.schedmd.com/slurm/slurm-21.08.8.tar.bz2
sudo apt install bzip2
tar -xvjf slurm-21.08.8.tar.bz2

# Step 2: Install necessary dependencies
sudo apt update
sudo apt install -y build-essential munge libmunge-dev libmunge2 libmysqlclient-dev \
  libssl-dev libpam-dev libnuma-dev perl mailutils mariadb-server slurm-client

# Step 3: Build and install Slurm
cd slurm-21.08.8
./configure --prefix=/home/${username}/slurm-21.08.8/
make
sudo make install

# Step 4: Set up Munge
sudo create-munge-key
sudo chown munge: /etc/munge/munge.key
sudo chmod 400 /etc/munge/munge.key
sudo systemctl enable munge
sudo systemctl start munge

# Step 5: Configure Slurm
[ ! -d "/etc/slurm-llnl" ] && sudo mkdir /etc/slurm-llnl
[ ! -d "/etc/slurm" ] && sudo mkdir /etc/slurm

cd /home/${username}/slurm-21.08.8/etc/
sudo cp -arfv slurm.conf.example slurm.conf

# Add configuration to slurm.conf
# sudo bash -c 'cat <<EOL > slurm.conf
# AuthType=auth/munge
# EOL'

sed -i -e "s/^ClusterName.*/ClusterName=cluster/" \
       -e "s/^SlurmctldHost.*/SlurmctldHost=${m_host}/" \
       -e '1s/^/AuthType=auth\/munge\n/' \
       -e "s/^ProctrackType.*/ProctrackType=proctrack\/linuxproc/" \
       -e "s/^AccountingStorageType.*/AccountingStorageType=accounting_storage\/slurmdbd/" \
       -e "s/^SlurmUser.*/SlurmUser=${username}/" \
       -e "s/^NodeName.*/NodeName=${m_host} CPUs=4 State=UNKNOWN/" \
       -e "/^NodeName.*${m_host}/a NodeName=${c_host1} CPUs=4 State=UNKNOWN" \
       -e "/^NodeName.*${m_host}/a NodeName=${c_host2} CPUs=4 State=UNKNOWN" \
       -e "s/^PartitionName.*/PartitionName=newpartition Nodes=ALL Default=YES MaxTime=INFINITE State=UP/" \
       -e "s/^MailProg.*/MailProg=\/usr\/bin\/mail/" slurm.conf


sudo cp -arfv slurm.conf /etc/slurm-llnl/
sudo cp -arfv slurm.conf /etc/slurm/

# Step 6: Configure Slurm Database Daemon (slurmdbd)
sudo cp -arfv slurmdbd.conf.example slurmdbd.conf

sed -i -e "s/^DbdAddr.*/DbdAddr=${m_ip}/" \
       -e "s/^DbdHost.*/DbdHost=${m_host}/" \
       -e "s/^SlurmUser.*/SlurmUser=${username}/" \
       -e "s/^StoragePass.*/StoragePass=password/" \
       -e "s/^StorageUser.*/StorageUser=${username}/" slurmdbd.conf

sudo chmod 600 slurmdbd.conf
sudo chown ${username}:${username} slurmdbd.conf

# Step 7: Configure MySQL for Slurm
sudo sed -i "s/^bind-address.*/bind-address = ${m_ip}/" /etc/mysql/mariadb.conf.d/50-server.cnf

sudo systemctl restart mariadb
sudo systemctl enable mariadb

command="CREATE USER '${username}'@'localhost' IDENTIFIED BY 'password'; GRANT ALL PRIVILEGES ON *.* TO '${username}'@'localhost'; FLUSH PRIVILEGES;"
sudo mysql -u root --password="password" -e "$command"

# Step 8: Set up required directories and permissions
sudo mkdir -p /var/spool/slurmctld
sudo chown ${username}:${username} /var/spool/slurmctld
sudo chmod 700 /var/spool/slurmctld/

# Step 9: Export necessary environment variables
export LD_LIBRARY_PATH="/home/ubuntu/slurm-21.08.8/lib:$LD_LIBRARY_PATH"
export PATH="/home/ubuntu/slurm-21.08.8/sbin/:$PATH"
export PATH="/home/ubuntu/slurm-21.08.8/bin/:$PATH"

# Add these exports to bashrc for persistence
echo 'export LD_LIBRARY_PATH="/home/ubuntu/slurm-21.08.8/lib:$LD_LIBRARY_PATH"' >> ~/.bashrc
echo 'export PATH="/home/ubuntu/slurm-21.08.8/sbin/:$PATH"' >> ~/.bashrc
echo 'export PATH="/home/ubuntu/slurm-21.08.8/bin/:$PATH"' >> ~/.bashrc
source ~/.bashrc


# Step 10: Deploy configuration files to compute nodes
echo "Deploying configuration to compute nodes..."

sudo scp "/etc/slurm/slurm.conf" "/etc/munge/munge.key" "${username}@${c_host1}:/tmp/"
sudo scp "/etc/slurm/slurm.conf" "/etc/munge/munge.key" "${username}@${c_host2}:/tmp/"


# sudo scp -r /etc/slurm/slurm.conf ${username}@${c_host1}:/tmp
# sudo scp -r /etc/munge/munge.key ${username}@${c_host1}:/tmp

# Step 11: Set up and enable Slurm services
sudo cp -arfv /home/${username}/slurm-21.08.8/etc/slurmctld.service /etc/systemd/system/
sudo cp -arfv /home/${username}/slurm-21.08.8/etc/slurmd.service /etc/systemd/system/
sudo cp -arfv /home/${username}/slurm-21.08.8/etc/slurmdbd.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable slurmdbd
sudo systemctl start slurmdbd
sudo systemctl enable munge
sudo systemctl start munge
sudo systemctl enable slurmctld
sudo systemctl start slurmctld
sudo systemctl enable slurmd
sudo systemctl start slurmd


# Step 12: Verify service statuses
echo "Verifying services..."
for service in munge slurmctld slurmd slurmdbd; do
    if systemctl is-active --quiet $service; then
        echo "$service is running"
    else
        echo "$service failed to start"
    fi
done

# Step 13: Check Slurm status and nodes

scontrol update nodename=${m_host} state=down reason=NA 
scontrol update nodename=worker[1-2] state=down reason=NA
scontrol update nodename=${m_host} state=idle
scontrol update nodename=worker[1-2] state=idle
sinfo