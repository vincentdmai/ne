#! /bin/bash
nitro_lookup_dir="/var/tmp"
sudo mkdir /var/lib/docker
sudo mkdir ${nitro_lookup_dir}
sudo /usr/bin/lsblk
sudo /usr/bin/df -h
# sudo cat /etc/fstab
sudo amazon-linux-extras install aws-nitro-enclaves-cli -y
sudo yum install aws-nitro-enclaves-cli-devel git -y
sudo usermod -aG ne ec2-user
sudo usermod -aG docker ec2-user
sudo echo "---
# Enclave configuration file.
#
# How much memory to allocate for enclaves (in MiB).
memory_mib: 4096
#
# How many CPUs to reserve for enclaves.
cpu_count: 2" > /etc/nitro_enclaves/allocator.yaml
sudo systemctl start nitro-enclaves-allocator.service && sudo systemctl enable nitro-enclaves-allocator.service
sudo systemctl start docker && sudo systemctl enable docker
sudo cp -R ./files/* ${nitro_lookup_dir}
sudo cp ${nitro_lookup_dir}/start*.sh /bin/
sudo cp ${nitro_lookup_dir}/terminate-enclave.sh /bin/terminate-enclave.sh
sudo cp ${nitro_lookup_dir}/nitro-lookup.sh /bin/nitro-lookup.sh
sudo chmod 0755 /bin/nitro-lookup.sh
sudo chmod 0755 /bin/terminate-enclave.sh
sudo chmod 0755 /bin/start-enclave*.sh
sudo cp ${nitro_lookup_dir}/nitro-lookup.service /etc/systemd/system/nitro-lookup.service
# sudo cp ${nitro_lookup_dir}/lookup-server.service /etc/systemd/system/lookup-server.service
sudo systemctl enable nitro-lookup.service
# sudo systemctl enable lookup-server.service
