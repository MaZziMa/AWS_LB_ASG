#!/bin/bash
# Check SSH configuration

echo "=== SSH Daemon Status ==="
systemctl status sshd | grep Active

echo -e "\n=== SSH Listening Ports ==="
ss -tlnp | grep :22

echo -e "\n=== SSH Config ==="
grep -v "^#" /etc/ssh/sshd_config | grep -v "^$" | head -20

echo -e "\n=== ec2-user SSH Keys ==="
ls -la /home/ec2-user/.ssh/ 2>&1

echo -e "\n=== Authorized Keys (first line) ==="
head -1 /home/ec2-user/.ssh/authorized_keys 2>&1
