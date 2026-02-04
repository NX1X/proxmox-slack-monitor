#!/bin/bash
# Proxmox Cluster Monitoring for Slack
# Part of NXTools Collection
# Author: NX1X (https://nx1xlab.dev)
# Repository: https://github.com/NX1X/proxmox-slack-monitor
# More tools: https://nx1xlab.dev/nxtools

WEBHOOK="https://hooks.slack.com/services/YOUR-WEBHOOK-URL"
STATE_FILE="/tmp/vm_states.txt"
ALERT_COOLDOWN=20  # 5 min cooldown between same alerts

# Thresholds
CPU_THRESHOLD=80 # Alert when usage ABOVE 80%
RAM_THRESHOLD=80 # Alert when usage ABOVE 80%
DISK_USAGE_THRESHOLD=70  # Alert when usage ABOVE 70%


touch $STATE_FILE

send_slack() {
    local emoji=$1
    local title=$2
    local message=$3
    local color=${4:-"warning"}
    
    # Add preview text for desktop notifications
    local preview="$emoji $title"
    
    curl -s -X POST "$WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "{
            \"text\": \"$preview\",
            \"attachments\": [{
                \"color\": \"$color\",
                \"blocks\": [{
                    \"type\": \"header\",
                    \"text\": {\"type\": \"plain_text\", \"text\": \"$emoji $title\"}
                }, {
                    \"type\": \"section\",
                    \"text\": {\"type\": \"mrkdwn\", \"text\": \"$message\"}
                }]
            }]
        }"
}

# VM Status Monitoring
monitor_vms() {
    while true; do
        pvesh get /cluster/resources --type vm --output-format json 2>/dev/null | jq -c '.[]' 2>/dev/null | while read vm; do
            VMID=$(echo $vm | jq -r '.vmid')
            STATUS=$(echo $vm | jq -r '.status')
            NODE=$(echo $vm | jq -r '.node')
            NAME=$(echo $vm | jq -r '.name // "VM-'$VMID'"')
            
            OLD_STATUS=$(grep "^$VMID:" $STATE_FILE 2>/dev/null | cut -d: -f2)
            
            if [ "$OLD_STATUS" != "$STATUS" ] && [ -n "$OLD_STATUS" ]; then
                if [ "$STATUS" == "running" ]; then
                    send_slack "🟢" "VM Started" "*$NAME* (ID: $VMID)\nNode: $NODE" "good"
                elif [ "$STATUS" == "stopped" ]; then
                    send_slack "🔴" "VM Stopped" "*$NAME* (ID: $VMID)\nNode: $NODE" "danger"
                fi
            fi
            
            sed -i "/^$VMID:/d" $STATE_FILE 2>/dev/null
            echo "$VMID:$STATUS" >> $STATE_FILE
        done
        
        sleep 10
    done
}

# Resource Monitoring (All Nodes)
monitor_resources() {
    while true; do
        pvesh get /cluster/resources --type node --output-format json 2>/dev/null | jq -c '.[]' 2>/dev/null | while read node; do
            NODE=$(echo $node | jq -r '.node')
            CPU=$(echo $node | jq -r '.cpu * 100 | floor')
            MEM=$(echo $node | jq -r '(.mem / .maxmem) * 100 | floor')
            DISK=$(echo $node | jq -r '(.disk / .maxdisk) * 100 | floor')
            
            # CPU Alert
            if [ "$CPU" -gt "$CPU_THRESHOLD" ]; then
                send_slack "⚠️" "High CPU Usage" "*Node:* $NODE\n*CPU:* ${CPU}%\n*Threshold:* ${CPU_THRESHOLD}%" "warning"
            fi
            
            # RAM Alert
            if [ "$MEM" -gt "$RAM_THRESHOLD" ]; then
                send_slack "⚠️" "High Memory Usage" "*Node:* $NODE\n*Memory:* ${MEM}%\n*Threshold:* ${RAM_THRESHOLD}%" "warning"
            fi
            
            # Disk Alert
            if [ ! -z "$DISK" ] && [ "$DISK" -gt "$DISK_USAGE_THRESHOLD" ]; then
               send_slack "⚠️" "High Disk Usage" "*Node:* $NODE\n*Disk Usage:* ${DISK}%\n*Threshold:* ${DISK_USAGE_THRESHOLD}%" "warning"
            fi
        done  # <-- ADD THIS LINE (closes the 'while read node' loop)
        
        sleep 300  # Check every 5 minutes
    done
}

# Storage/ZFS Monitoring
monitor_storage() {
    while true; do
        # Check ZFS pools on all nodes
        for node in $(pvesh get /nodes --output-format json | jq -r '.[].node'); do
            ssh -o ConnectTimeout=5 root@$node 'zpool status 2>/dev/null' | grep -q DEGRADED && \
                send_slack "🔴" "ZFS Pool Degraded" "*Node:* $node\nZFS pool health degraded!" "danger"
        done
        
        sleep 600  # Check every 10 minutes
    done
}

# Security Monitoring
monitor_security() {
    while true; do
        # Failed SSH attempts (last 5 minutes)
        for node in $(pvesh get /nodes --output-format json | jq -r '.[].node'); do
            FAILED=$(ssh -o ConnectTimeout=5 root@$node "journalctl -u ssh --since '5 min ago' 2>/dev/null | grep -c 'Failed password'" 2>/dev/null)
            if [ "$FAILED" -gt 5 ]; then
                send_slack "🚨" "Security Alert" "*Node:* $node\n*Failed SSH attempts:* $FAILED in last 5 min" "danger"
            fi
        done
        
        sleep 300
    done
}

# Start all monitors in background
monitor_vms &
monitor_resources &
monitor_storage &
monitor_security &

# Keep script running
wait
