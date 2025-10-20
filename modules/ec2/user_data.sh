#!/bin/bash
################################################################################
# EC2 User Data Script Template
# Description: Bootstrap script for Amazon Linux 2023 / Amazon Linux 2
################################################################################

set -e

# Variables (replace with your values or use template variables)
ENVIRONMENT="${environment}"
PROJECT_NAME="${project_name}"
APPLICATION="${application}"

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "EC2 Instance Bootstrap Starting"
echo "Time: $(date)"
echo "Instance ID: $(ec2-metadata --instance-id | cut -d ' ' -f 2)"
echo "=========================================="

################################################################################
# System Updates
################################################################################

echo "[1/8] Updating system packages..."
yum update -y

################################################################################
# Install CloudWatch Agent
################################################################################

echo "[2/8] Installing CloudWatch Agent..."
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'EOF'
{
  "metrics": {
    "namespace": "CustomMetrics/${project_name}",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"},
          {"name": "cpu_usage_iowait", "rename": "CPU_IOWAIT", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          {"name": "used_percent", "rename": "DISK_USED", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": [
          {"name": "mem_used_percent", "rename": "MEM_USED", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/${project_name}-${environment}",
            "log_stream_name": "{instance_id}/messages"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/${project_name}-${environment}",
            "log_stream_name": "{instance_id}/user-data"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

################################################################################
# Install Common Tools
################################################################################

echo "[3/8] Installing common tools..."
yum install -y \
  htop \
  vim \
  git \
  jq \
  unzip \
  wget \
  curl \
  nc \
  telnet

################################################################################
# Install AWS CLI v2 (if not present)
################################################################################

echo "[4/8] Checking AWS CLI..."
if ! command -v aws &> /dev/null; then
  echo "Installing AWS CLI v2..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
  rm -rf aws awscliv2.zip
fi

aws --version

################################################################################
# Configure System Settings
################################################################################

echo "[5/8] Configuring system settings..."

# Set timezone
timedatectl set-timezone UTC

# Configure limits
cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
EOF

# Configure sysctl
cat >> /etc/sysctl.conf << 'EOF'
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65535
EOF

sysctl -p

################################################################################
# Install Docker (optional - uncomment if needed)
################################################################################

echo "[6/8] Installing Docker (optional)..."
# yum install -y docker
# systemctl start docker
# systemctl enable docker
# usermod -a -G docker ec2-user

################################################################################
# Create Application Directory Structure
################################################################################

echo "[7/8] Setting up application directories..."
mkdir -p /opt/app/{bin,config,logs,data}
chown -R ec2-user:ec2-user /opt/app

################################################################################
# Instance Tagging and Metadata
################################################################################

echo "[8/8] Configuring instance metadata..."

# Get instance details
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)
INSTANCE_TYPE=$(ec2-metadata --instance-type | cut -d ' ' -f 2)
AZ=$(ec2-metadata --availability-zone | cut -d ' ' -f 2)

# Store metadata
cat > /opt/app/config/instance-info.json << EOF
{
  "instance_id": "$INSTANCE_ID",
  "instance_type": "$INSTANCE_TYPE",
  "availability_zone": "$AZ",
  "environment": "$ENVIRONMENT",
  "project": "$PROJECT_NAME",
  "application": "$APPLICATION",
  "bootstrap_time": "$(date -Iseconds)"
}
EOF

################################################################################
# Health Check Script
################################################################################

cat > /opt/app/bin/health-check.sh << 'HEALTH'
#!/bin/bash
# Simple health check script

# Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 90 ]; then
  echo "ERROR: Disk usage above 90%"
  exit 1
fi

# Check memory
MEM_AVAILABLE=$(free | grep Mem | awk '{print ($7/$2) * 100.0}')
if (( $(echo "$MEM_AVAILABLE < 10" | bc -l) )); then
  echo "WARNING: Low memory available"
fi

# Check if critical services are running
# Add your application-specific checks here

echo "OK: Health check passed"
exit 0
HEALTH

chmod +x /opt/app/bin/health-check.sh

################################################################################
# Completion
################################################################################

echo "=========================================="
echo "EC2 Instance Bootstrap Complete"
echo "Time: $(date)"
echo "=========================================="

# Signal CloudFormation/ASG (if using lifecycle hooks)
# aws autoscaling complete-lifecycle-action ...

exit 0

