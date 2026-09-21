#!/usr/bin/env bash
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2026 Sean Korten
# Author: Sean Korten
# License: MIT
# Source: https://github.com/voska/hass-mcp

APP="Hass-MCP"
var_tags="${var_tags:-home-assistant;mcp;ai}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
#var_arm64="${var_arm64:-no}" # unset = ask the user; set yes/no only when verified
var_unprivileged="${var_unprivileged:-1}"
var_ha_url="${var_ha_url:-}"
var_ha_token="${var_ha_token:-}"
var_mcp_port="${var_mcp_port:-8000}"

header_info "$APP"
variables
color
catch_errors

if command -v pveversion >/dev/null 2>&1; then
  if [[ -z "$var_ha_url" ]]; then
    var_ha_url=$(prompt_input "Home Assistant URL:" "http://homeassistant.local:8123" 120)
  fi
  if [[ -z "$var_ha_token" ]]; then
    var_ha_token=$(prompt_password "Home Assistant long-lived access token:" "" 120)
  fi
  if [[ -z "$var_ha_token" ]]; then
    msg_error "A Home Assistant long-lived access token is required. Set var_ha_token and retry."
    exit 1
  fi
  if ! [[ "$var_mcp_port" =~ ^[0-9]+$ ]] || ((var_mcp_port < 1 || var_mcp_port > 65535)); then
    msg_error "var_mcp_port must be an integer between 1 and 65535."
    exit 1
  fi
fi

export var_ha_url var_ha_token var_mcp_port

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -x /opt/hass-mcp/bin/hass-mcp ]]; then
    msg_error "No ${APP} Installation Found!"
    exit 1
  fi

  if check_for_gh_release "hass-mcp" "voska/hass-mcp"; then
    msg_info "Stopping Hass-MCP"
    systemctl stop hass-mcp
    msg_ok "Stopped Hass-MCP"

    HASS_MCP_VERSION="$(get_latest_github_release "voska/hass-mcp")"
    msg_info "Updating Hass-MCP"
    $STD uv pip install --python /opt/hass-mcp/bin/python --upgrade "hass-mcp==${HASS_MCP_VERSION}"
    cat <<EOF >~/.hass-mcp
${HASS_MCP_VERSION}
EOF
    msg_ok "Updated Hass-MCP"

    msg_info "Starting Hass-MCP"
    systemctl start hass-mcp
    msg_ok "Started Hass-MCP"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}MCP endpoint:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:${var_mcp_port}/mcp${CL}"
