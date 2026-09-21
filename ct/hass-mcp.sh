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
var_mcp_port="${var_mcp_port:-}"

header_info "$APP"
variables
color
catch_errors

function collect_app_settings() {
  local result
  local can_prompt=true

  if ! command -v whiptail &>/dev/null || [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
    can_prompt=false
  fi

  if [[ -z "$var_ha_url" ]]; then
    if [[ "$can_prompt" == true ]]; then
      if ! result=$(whiptail \
        --backtitle "Proxmox VE Helper Scripts" \
        --title "HOME ASSISTANT URL" \
        --ok-button "Next" --cancel-button "Exit Script" \
        --inputbox "Enter the URL of the existing Home Assistant instance.\n\nInclude the scheme and port." \
        13 68 "http://homeassistant.local:8123" \
        3>&1 1>&2 2>&3 </dev/tty); then
        exit_script
      fi
      var_ha_url="${result:-http://homeassistant.local:8123}"
    else
      var_ha_url="http://homeassistant.local:8123"
    fi
  fi

  if [[ -z "$var_ha_token" ]]; then
    if [[ "$can_prompt" == true ]]; then
      while [[ -z "$var_ha_token" ]]; do
        if ! result=$(whiptail \
          --backtitle "Proxmox VE Helper Scripts" \
          --title "HOME ASSISTANT TOKEN" \
          --ok-button "Next" --cancel-button "Exit Script" \
          --passwordbox "Enter a Home Assistant long-lived access token.\n\nInput is hidden." \
          13 68 \
          3>&1 1>&2 2>&3 </dev/tty); then
          exit_script
        fi
        var_ha_token="$result"
        if [[ -z "$var_ha_token" ]]; then
          whiptail \
            --backtitle "Proxmox VE Helper Scripts" \
            --title "TOKEN REQUIRED" \
            --msgbox "A Home Assistant long-lived access token is required." \
            9 60 </dev/tty
        fi
      done
    else
      msg_error "var_ha_token is required when no interactive terminal is available."
      exit 1
    fi
  fi

  if [[ -z "$var_mcp_port" ]]; then
    if [[ "$can_prompt" == true ]]; then
      while true; do
        if ! result=$(whiptail \
          --backtitle "Proxmox VE Helper Scripts" \
          --title "MCP HTTP PORT" \
          --ok-button "Continue" --cancel-button "Exit Script" \
          --inputbox "Enter the port for the Hass-MCP Streamable HTTP endpoint." \
          11 68 "8000" \
          3>&1 1>&2 2>&3 </dev/tty); then
          exit_script
        fi
        result="${result:-8000}"
        if [[ "$result" =~ ^[0-9]+$ ]] && ((${#result} <= 5)) && ((10#$result >= 1 && 10#$result <= 65535)); then
          var_mcp_port="$result"
          break
        fi
        whiptail \
          --backtitle "Proxmox VE Helper Scripts" \
          --title "INVALID PORT" \
          --msgbox "Enter an integer between 1 and 65535." \
          9 60 </dev/tty
      done
    else
      var_mcp_port="8000"
    fi
  fi

  if ! [[ "$var_mcp_port" =~ ^[0-9]+$ ]] || ((${#var_mcp_port} > 5)) || ((10#$var_mcp_port < 1 || 10#$var_mcp_port > 65535)); then
    msg_error "var_mcp_port must be an integer between 1 and 65535."
    exit 1
  fi
  var_mcp_port="$((10#$var_mcp_port))"

  export var_ha_url var_ha_token var_mcp_port
}

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
collect_app_settings
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}MCP endpoint:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:${var_mcp_port}/mcp${CL}"
