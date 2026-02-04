# Proxmox Cluster Slack Monitoring


![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Proxmox](https://img.shields.io/badge/Proxmox-VE%207%2F8-orange.svg)
[![Slack](https://custom-icon-badges.demolab.com/badge/Slack-4A154B?logo=slack&logoColor=fff)](#)
![Bash](https://img.shields.io/badge/bash-5.0%2B-green.svg)
![Platform](https://img.shields.io/badge/platform-Debian%2011%2F12-red.svg)
![Status](https://img.shields.io/badge/status-active-brightgreen.svg)
![Visitors](https://visitor-badge.laobi.icu/badge?page_id=NX1X.proxmox-slack-monitor)



Real-time monitoring system for Proxmox VE clusters with Slack notifications via API-based cluster-wide monitoring.

## Features

- **VM Operations** - Start/Stop/Status change alerts across all nodes
- **Resource Monitoring** - CPU, RAM, and Disk usage threshold alerts
- **ZFS Health** - Pool degradation detection and warnings
- **Security Monitoring** - Failed SSH login attempt detection
- **Cluster-Wide** - Single script monitors entire cluster from manager node
- **API-Based** - Uses Proxmox API for comprehensive visibility

## Requirements

- Proxmox VE 7.x or 8.x
- Debian 11 (Bullseye) or 12 (Bookworm)
- `jq` package for JSON parsing
- SSH key-based authentication between cluster nodes
- Slack workspace with incoming webhook

## Installation

### 1. Slack Setup

See [SLACK_SETUP.md](SLACK_SETUP.md) for complete Slack configuration guide.

**Quick steps:**
1. Create Slack incoming webhook
2. Configure in Proxmox UI (Datacenter → Notifications)
3. Add webhook URL to monitoring script
4. Test and verify alerts

[Full setup instructions →](SLACK_SETUP.md)


### 2. Install Dependencies
```bash
apt update && apt install -y jq
```

### 3. Download and Configure Script
```bash
# Download script
wget https://raw.githubusercontent.com/NX1X/proxmox-slack-monitor/main/proxmox-cluster-monitor.sh

# Make executable
chmod +x proxmox-cluster-monitor.sh

# Move to system location
mv proxmox-cluster-monitor.sh /usr/local/bin/

# Edit configuration
nano /usr/local/bin/proxmox-cluster-monitor.sh
```

Edit the `WEBHOOK` variable with your Slack webhook URL:
```bash
WEBHOOK="https://hooks.slack.com/services/YOUR-WEBHOOK-URL"
```

### 4. Setup SSH Keys

Run from your cluster manager node:
```bash
# Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/cluster_key -N ""

# Distribute to all cluster nodes
for node in node1 node2 node3 node4; do
  ssh-copy-id -i ~/.ssh/cluster_key root@$node
done
```

### 5. Create Systemd Service
```bash
cat > /etc/systemd/system/proxmox-cluster-monitor.service << 'EOF'
[Unit]
Description=Proxmox Cluster-wide Monitoring
After=network.target pveproxy.service pvestatd.service

[Service]
Type=simple
ExecStart=/usr/local/bin/proxmox-cluster-monitor.sh
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF
```

### 6. Enable and Start Service
```bash
systemctl daemon-reload
systemctl enable proxmox-cluster-monitor
systemctl start proxmox-cluster-monitor
systemctl status proxmox-cluster-monitor
```

## Configuration

### Alert Thresholds

Edit these variables in the script to customize alert sensitivity:
```bash
CPU_THRESHOLD=80        # Alert when CPU usage exceeds 80%
RAM_THRESHOLD=80        # Alert when RAM usage exceeds 80%
DISK_USAGE_THRESHOLD=70 # Alert when disk usage exceeds 70%
```

### Monitoring Intervals
```bash
VM monitoring:       Every 10 seconds
Resource monitoring: Every 5 minutes
ZFS health:          Every 10 minutes
Security checks:     Every 5 minutes
```

## Alert Types and Triggers

| Alert Type | Trigger Condition | Severity | Frequency |
|-----------|-------------------|----------|-----------|
| VM Started | VM state changes to running | Info | Instant |
| VM Stopped | VM state changes to stopped | Warning | Instant |
| High CPU Usage | CPU exceeds threshold | Warning | 5 minutes |
| High Memory Usage | RAM exceeds threshold | Warning | 5 minutes |
| High Disk Usage | Disk exceeds threshold | Warning | 5 minutes |
| ZFS Pool Degraded | Pool status is DEGRADED | Critical | 10 minutes |
| Security Alert | More than 5 failed SSH attempts | Critical | 5 minutes |

## Slack Webhook Setup

1. Navigate to https://api.slack.com/messaging/webhooks
2. Create a new incoming webhook
3. Select the channel for notifications
4. Copy the webhook URL
5. Add URL to the `WEBHOOK` variable in script

## Slack Message Format

Alerts include:
- Severity indicator (color-coded)
- Alert title with emoji
- Node information
- Detailed status information
- Timestamp

## Troubleshooting

### Service Not Starting
```bash
# Check service status
systemctl status proxmox-cluster-monitor

# View logs
journalctl -u proxmox-cluster-monitor -n 50 --no-pager

# Test script manually
bash -n /usr/local/bin/proxmox-cluster-monitor.sh

# Check permissions
ls -la /usr/local/bin/proxmox-cluster-monitor.sh
```

### No Alerts Appearing
```bash
# Test Slack webhook manually
curl -X POST -H 'Content-Type: application/json' \
  --data '{"text":"Test from Proxmox"}' \
  YOUR-WEBHOOK-URL

# Check SSH connectivity
for node in node1 node2; do
  ssh -o ConnectTimeout=5 root@$node "hostname"
done

# Monitor script logs
journalctl -u proxmox-cluster-monitor -f
```

### High Resource Usage

If monitoring script uses too much CPU/RAM:
- Increase monitoring intervals in script
- Reduce number of monitored metrics
- Check for SSH connection issues

## Tested Environments

- Proxmox VE 8.x on Debian 12 (Bookworm)
- Proxmox VE 7.x on Debian 11 (Bullseye)
- Cluster sizes: 3-7 nodes
- Mixed node configurations (different hardware specs)

## Architecture

The script runs on your cluster manager node and:
1. Uses Proxmox API (`pvesh`) for cluster-wide VM monitoring
2. Polls resource usage from all nodes via API
3. SSH to individual nodes for ZFS and security checks
4. Maintains VM state file for change detection
5. Sends formatted JSON to Slack webhook

## Security Considerations

- Script runs as root (required for Proxmox API access)
- SSH keys stored in `/root/.ssh/`
- Webhook URL contains sensitive token
- No sensitive data logged or transmitted
- State file stored in `/tmp/` (cleared on reboot)

## Performance Impact

- Minimal CPU usage (background monitoring)
- Memory footprint: ~10-20MB
- Network: Periodic API calls and SSH checks
- No impact on VM or container performance

## License

MIT License - see LICENSE file for details

## Author & Project

This project is part of the **NXTools Collection** - a suite of open-source tools for infrastructure automation and monitoring.

### NXTools Collection

Explore more tools and projects:
- 🌐 **Website:** [nx1xlab.dev](https://nx1xlab.dev)
- 🛠️ **NXTools:** [nx1xlab.dev/nxtools](https://nx1xlab.dev/nxtools)
- 📝 **Technical Blog:** [blog.nx1xlab.dev](https://blog.nx1xlab.dev)

### Connect

- **GitHub:** [@NX1X](https://github.com/NX1X)
- **LinkedIN:** [linkedin.com](https://LinkedIn.com/in/edenporat)
- **Contact form:** [nx1xlab.dev/contact](https://blog.nx1xlab.dev/contact)

**GitHub Topics/Tags:**
```
proxmox
proxmox-ve
monitoring
alerting
slack
slack-notifications
homelab
cluster-monitoring
zfs
devops
bash
automation
sysadmin
infrastructure
virtualization
---