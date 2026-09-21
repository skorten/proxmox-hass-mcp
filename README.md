# Proxmox Hass-MCP

`proxmox-hass-mcp` creates a dedicated Debian 13 LXC on Proxmox VE and installs [Hass-MCP](https://github.com/voska/hass-mcp) as a systemd service using MCP Streamable HTTP transport.

The resulting MCP endpoint can be shared by network-based clients without running Docker inside the LXC.

> [!IMPORTANT]
> This is an independent project. It is not affiliated with, endorsed by, or maintained by the Hass-MCP project, Proxmox Server Solutions GmbH, or the Community Scripts / Proxmox VE Helper-Scripts project.

This project depends on work maintained by those communities. Thanks to the Hass-MCP developers for the Home Assistant MCP server, the Proxmox developers for the virtualization platform, and the Community Scripts maintainers for the LXC creation and application-installation framework.

## Why this project exists

Hass-MCP supports Streamable HTTP, but its upstream deployment instructions primarily cover `uvx` and Docker. This project packages the bare-metal Python installation as a repeatable Proxmox helper script with:

- Debian 13 LXC creation
- Python 3.13 and `uv`
- A persistent systemd service
- Guided Home Assistant configuration
- Protected token storage
- Persistent dashboard backups
- An update command that follows stable Hass-MCP releases
- Community Scripts-compatible file organization

Implementation details are documented in [Architecture and implementation](ARCHITECTURE.md).

## Default deployment

| Setting | Default |
| --- | ---: |
| Container type | Unprivileged Debian 13 LXC |
| CPU | 1 core |
| Memory | 512 MiB |
| Disk | 4 GiB |
| MCP port | 8000 |
| MCP path | `/mcp` |

The default endpoint is:

```text
http://<LXC-IP>:8000/mcp
```

## Requirements

- A Proxmox VE host
- Root access to the Proxmox host shell
- A Home Assistant instance reachable from the new LXC
- A Home Assistant long-lived access token
- DNS that works inside the LXC when Home Assistant is addressed by hostname

ARM64 is not currently advertised because this project has not been tested on an ARM64 Proxmox host.

## Create a Home Assistant token

1. Sign in to Home Assistant as the user Hass-MCP should act as.
2. Open that user's profile page.
3. Find **Long-Lived Access Tokens**.
4. Create a token named `Hass-MCP`.
5. Copy the complete token when it is displayed. Home Assistant does not display it again.

The token inherits the permissions of its Home Assistant user. A dedicated user is recommended so the integration is not tied to a personal account.

See the [Home Assistant authentication documentation](https://developers.home-assistant.io/docs/auth_api/#long-lived-access-token) for additional details.

## Install

Run the following command from the Proxmox VE host shell:

```bash
curl -fsSL https://raw.githubusercontent.com/community-scripts/core/main/tools/run.sh |
  bash -s -- https://raw.githubusercontent.com/skorten/proxmox-hass-mcp/main ct/hass-mcp.sh
```

The installer asks for:

- The Home Assistant URL, including scheme and port
- The Home Assistant long-lived access token; terminal input is hidden
- The MCP port, which defaults to `8000`
- Standard LXC settings such as container ID, storage, network, and resources

For the Home Assistant URL, use an address that is reachable from another LXC. Examples:

```text
http://homeassistant.local:8123
http://192.0.2.10:8123
https://home-assistant.example.internal
```

Do not use `localhost` unless Home Assistant is running inside the same LXC.

## Connect an MCP client

Configure the client for **Streamable HTTP** and use:

```text
http://<LXC-IP>:8000/mcp
```

Replace the address with the LXC IP shown when installation completes. If a custom port was selected, replace `8000` with that port.

MCP client configuration formats differ. Use the URL above wherever the client requests its remote MCP server or Streamable HTTP endpoint.

## Security

Hass-MCP does not authenticate clients that connect to its HTTP transport. The service binds to all LXC interfaces so that remote MCP clients can reach it. Anyone who can reach the endpoint can use the Home Assistant permissions granted to its token.

Do not expose port `8000` directly to the public internet. Restrict access using one or more of:

- Proxmox, host, or network firewall rules
- A trusted management VLAN
- WireGuard, Tailscale, or another VPN
- A zero-trust access platform
- An authenticated HTTPS reverse proxy

The Home Assistant token is stored at `/opt/hass-mcp_data/hass-mcp.env`. The installer sets this file to mode `600`.

## Operate the service

Run service commands inside the LXC:

```bash
systemctl status hass-mcp
systemctl restart hass-mcp
journalctl -u hass-mcp -f
```

Hass-MCP starts automatically with the LXC and restarts after process failures.

## Update Hass-MCP

Run inside the LXC:

```bash
update
```

The updater checks the latest stable Hass-MCP release, upgrades the matching PyPI package, and restarts the service. Configuration and dashboard backups are stored outside the Python environment and remain in place.

## Change configuration

Edit the protected environment file inside the LXC:

```bash
nano /opt/hass-mcp_data/hass-mcp.env
systemctl restart hass-mcp
```

The file controls:

- `HA_URL`
- `HA_TOKEN`
- `MCP_HOST`
- `MCP_PORT`
- `HASS_MCP_BACKUP_DIR`

Dashboard backups created before Hass-MCP changes a Home Assistant dashboard are stored in:

```text
/opt/hass-mcp_data/dashboard-backups
```

Include `/opt/hass-mcp_data` in the normal LXC backup policy.

## Troubleshooting

View service state and recent logs:

```bash
systemctl status hass-mcp --no-pager
journalctl -u hass-mcp -n 100 --no-pager
```

Verify Home Assistant connectivity without placing the token directly in the command history:

```bash
set -a
source /opt/hass-mcp_data/hass-mcp.env
set +a
curl -fsS -H "Authorization: Bearer ${HA_TOKEN}" "${HA_URL}/api/"
```

Confirm that Hass-MCP is listening on the default port:

```bash
ss -lntp | grep ':8000'
```

For a custom port, substitute the configured value. If the service is listening but the client cannot connect, check the Proxmox firewall, LXC firewall, VLAN or subnet routing, and any intervening ACLs.

## Repository contents

```text
ct/hass-mcp.sh                  LXC creation and update logic
install/hass-mcp-install.sh     In-container application installation
json/hass-mcp.json              Community Scripts-compatible metadata
README.md                       Operator documentation
ARCHITECTURE.md                 Architecture and maintainer reference
LICENSE                         MIT license
```

## Validation status

The shell scripts pass Bash syntax validation, and the metadata parses as JSON. The Python 3.13 installation and Streamable HTTP entrypoint were tested by initializing an MCP client and listing the server's tools.

A complete create, reboot, backup, restore, and update cycle on a Proxmox VE host is still required before the project should be considered production-tested.

## License

This project is available under the [MIT License](LICENSE).
