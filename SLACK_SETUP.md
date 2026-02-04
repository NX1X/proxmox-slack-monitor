# Slack Webhook Setup Guide

![Proxmox](https://img.shields.io/badge/Proxmox-VE%207%2F8-orange.svg)
[![Slack](https://custom-icon-badges.demolab.com/badge/Slack-4A154B?logo=slack&logoColor=fff)](#)
![Visitors](https://visitor-badge.laobi.icu/badge?page_id=NX1X.proxmox-slack-monitor)

Complete guide for configuring Slack notifications with Proxmox.

## Prerequisites

- Slack workspace with permission to add apps
- Proxmox cluster installed and accessible
- See [README.md](README.md) for system requirements

## Part 1: Create Slack Incoming Webhook

### Step 1: Create Slack App

1. Go to https://api.slack.com/apps
2. Click **"Create New App"** → **"From scratch"**
3. Configure:
   - App name: `Proxmox Monitor`
   - Select your workspace
4. Click **"Create App"**

### Step 2: Enable Incoming Webhook

1. In app settings, click **"Incoming Webhooks"** (left sidebar)
2. Toggle **"Activate Incoming Webhooks"** to **ON**
3. Click **"Add New Webhook to Workspace"**
4. Select notification channel (e.g., `#infrastructure`, `#alerts`)
5. Click **"Allow"**

### Step 3: Copy Webhook URL

You'll receive a webhook URL like:
```
https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
```

**Important:** Keep this URL private - it allows posting to your Slack channel.

## Part 2: Configure Proxmox Built-in Notifications

This enables Proxmox to send backup alerts, storage issues, and system events.

### Step 1: Add Webhook Target

1. Proxmox UI → **Datacenter** → **Notifications** → **Notification Targets**
2. Click **"Add"** → **"Webhook"**
3. Configure webhook:

**Basic Settings:**
- **Endpoint Name:** `proxmox-slack`
- **Method:** `POST`
- **URL:** Paste your webhook URL from Part 1
- **Enable:** ✓ Check this box

**Headers:**
- Click **"Add Header"**
- **Name:** `Content-Type`
- **Value:** `application/json`

**Body:**
- Open [`slack-webhook-body.json`](slack-webhook-body.json) in this repository
- Copy the entire JSON content
- Paste into the **Body** field

4. Click **"OK"** to save

### Step 2: Test Built-in Notification

1. In Notification Targets list, select `proxmox-slack`
2. Click **"Test"** button
3. Check Slack - you should see a test message

### Step 3: Create Notification Matcher

This routes Proxmox events to Slack:

1. Click **"Notification Matchers"** tab
2. Click **"Add"**
3. Configure:
   - **Matcher Name:** `slack-all-events`
   - **Target:** Select `proxmox-slack` from dropdown
   - **Match Severity:** Check all boxes:
     - `info`
     - `notice`
     - `warning`
     - `error`
     - `unknown`
   - **Enable:** ✓ Check this box
4. Click **"OK"**

**Done!** Proxmox will now send notifications to Slack automatically.

## Part 3: Configure Cluster Monitoring Script

This adds custom VM and resource monitoring alerts.

### Step 1: Install Monitoring Script

Follow the installation instructions in [README.md](README.md#installation).

### Step 2: Add Webhook to Script

Edit the monitoring script:
```bash
nano /usr/local/bin/proxmox-cluster-monitor.sh
```

Find this line:
```bash
WEBHOOK="https://hooks.slack.com/services/YOUR-WEBHOOK-URL"
```

Replace with your actual webhook URL from Part 1.

Save the file (Ctrl+O, Enter, Ctrl+X).

### Step 3: Restart Monitoring Service
```bash
systemctl restart proxmox-cluster-monitor
systemctl status proxmox-cluster-monitor
```

Verify status shows `active (running)`.

## Testing Complete Setup

### Test Built-in Notifications

Run a backup:
```bash
vzdump 100 --storage local --mode snapshot
```

Check Slack for backup completion alert.

### Test Monitoring Script

Stop and start a VM:
```bash
qm stop 100
sleep 5
qm start 100
```

Check Slack for VM start/stop alerts.

## What You'll Receive

### Built-in Proxmox Notifications

Sent via webhook target configuration:
- Backup job success/failure
- Storage issues and warnings
- Certificate expiration notices
- Replication failures
- HA state changes
- Cluster quorum issues

### Custom Monitoring Alerts

Sent via monitoring script:
- VM start/stop events (all cluster nodes)
- High CPU usage (>80%)
- High RAM usage (>80%)
- High disk usage (>70%)
- ZFS pool health degradation
- Failed SSH login attempts (>5 in 5 minutes)

## Customization

### Adjust Alert Thresholds

Edit monitoring script:
```bash
nano /usr/local/bin/proxmox-cluster-monitor.sh
```

Modify these values:
```bash
CPU_THRESHOLD=80        # Change to your preference
RAM_THRESHOLD=80        # Change to your preference
DISK_USAGE_THRESHOLD=70 # Change to your preference
```

Restart service after changes:
```bash
systemctl restart proxmox-cluster-monitor
```

### Change Notification Channel

To send alerts to a different Slack channel:
1. In Slack app settings, add another webhook URL for new channel
2. Update `WEBHOOK` variable in script
3. Or create separate webhook target in Proxmox for different event types

### Customize Message Format

The [`slack-webhook-body.json`](slack-webhook-body.json) file controls message appearance:
- Modify emojis
- Change color scheme
- Adjust field layout
- Add/remove information

After editing, update the webhook target Body field in Proxmox UI.

## Troubleshooting

### Slack Webhook Issues

**Test webhook manually:**
```bash
curl -X POST -H 'Content-Type: application/json' \
  --data '{"text":"Test from Proxmox"}' \
  YOUR-WEBHOOK-URL
```

If this fails:
- Verify webhook URL is correct
- Check network connectivity: `ping hooks.slack.com`
- Ensure webhook hasn't been revoked in Slack

**Check Proxmox webhook:**
- Use "Test" button in Notification Targets
- Review error messages in Proxmox logs
- Verify JSON body is properly formatted

### Monitoring Script Issues

See [README.md - Troubleshooting](README.md#troubleshooting) for:
- Service startup problems
- SSH connectivity issues
- Log analysis commands

### Message Not Formatted

If messages appear as plain text:
- Verify `Content-Type: application/json` header is set
- Check JSON body is copied exactly from `slack-webhook-body.json`
- Ensure no extra characters or line breaks
- Test with simple message first, then add formatting

### Rate Limiting

Slack webhooks limit:
- 1 message per second average
- Bursts up to 30 per minute

If hitting limits:
- Increase monitoring check intervals
- Reduce alert frequency
- Consider alert aggregation

## Security Best Practices

### Protect Webhook URL

- Never commit webhook URLs to public repositories
- Use environment variables for sensitive data
- Rotate webhooks periodically
- Restrict Proxmox UI access

### Limit Exposure

- Use private Slack channels for sensitive alerts
- Review who has access to notification channels
- Monitor webhook usage in Slack app analytics
- Disable/delete unused webhooks

## Additional Resources

- Slack API Documentation: https://api.slack.com/messaging/webhooks
- Slack Block Kit Builder: https://app.slack.com/block-kit-builder
- Proxmox Notifications: https://pve.proxmox.com/wiki/Notifications
- Installation & Configuration: [README.md](README.md)

---

**Setup Complete!** Your Proxmox cluster now sends comprehensive alerts to Slack.

**Part of [NXTools Collection](https://nx1xlab.dev/nxtools)** by [NX1X](https://nx1xlab.dev)
