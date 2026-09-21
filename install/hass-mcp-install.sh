#!/usr/bin/env bash

# Copyright (c) 2026 Sean Korten
# Author: Sean Korten
# License: MIT
# Source: https://github.com/voska/hass-mcp

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

var_ha_url="${var_ha_url:-}"
var_ha_token="${var_ha_token:-}"
var_mcp_port="${var_mcp_port:-8000}"

if [[ -z "$var_ha_url" ]]; then
  read -r -p "${TAB3}Home Assistant URL (default: http://homeassistant.local:8123): " var_ha_url
fi
var_ha_url="${var_ha_url:-http://homeassistant.local:8123}"

if [[ -z "$var_ha_token" ]]; then
  read -r -s -p "${TAB3}Home Assistant long-lived access token: " var_ha_token
  echo
fi
if [[ -z "$var_ha_token" ]]; then
  msg_error "No Home Assistant long-lived access token provided. Cannot continue."
  exit 1
fi

if ! [[ "$var_mcp_port" =~ ^[0-9]+$ ]] || ((var_mcp_port < 1 || var_mcp_port > 65535)); then
  msg_error "var_mcp_port must be an integer between 1 and 65535."
  exit 1
fi

PYTHON_VERSION="3.13" setup_uv

HASS_MCP_VERSION="$(get_latest_github_release "voska/hass-mcp")"
msg_info "Installing Hass-MCP"
$STD uv venv --python 3.13 /opt/hass-mcp
$STD uv pip install --python /opt/hass-mcp/bin/python "hass-mcp==${HASS_MCP_VERSION}"
cat <<EOF >~/.hass-mcp
${HASS_MCP_VERSION}
EOF
msg_ok "Installed Hass-MCP"

msg_info "Configuring Hass-MCP"
mkdir -p /opt/hass-mcp_data/dashboard-backups
cat <<EOF >/opt/hass-mcp_data/hass-mcp.env
HA_URL=${var_ha_url}
HA_TOKEN=${var_ha_token}
HASS_MCP_BACKUP_DIR=/opt/hass-mcp_data/dashboard-backups
MCP_TRANSPORT=streamable-http
MCP_HOST=0.0.0.0
MCP_PORT=${var_mcp_port}
PYTHONUNBUFFERED=1
EOF
chmod 600 /opt/hass-mcp_data/hass-mcp.env
msg_ok "Configured Hass-MCP"

msg_info "Creating Hass-MCP Service"
cat <<EOF >/etc/systemd/system/hass-mcp.service
[Unit]
Description=Hass-MCP Streamable HTTP Server
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/hass-mcp_data
EnvironmentFile=/opt/hass-mcp_data/hass-mcp.env
ExecStart=/opt/hass-mcp/bin/hass-mcp --http
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now hass-mcp
msg_ok "Created Hass-MCP Service"

motd_ssh
customize
cleanup_lxc
