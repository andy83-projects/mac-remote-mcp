# HTTPS and network Settings

This branch adds source changes only. It does **not** change the running MacRemoteMCP application, its saved settings, or Hermes's existing HTTP endpoint. The installed app must eventually be updated with a built release before these Settings controls become available. No app bundle was rebuilt, replaced, or restarted as part of this work.

## Settings controls

- **Localhost only:** binds `127.0.0.1`; remote clients cannot connect directly.
- **Specific LAN IP:** enter an IP assigned to this Mac, e.g. `10.0.0.53`. Avoid DHCP changes by reserving the address. The OS rejects binding an unassigned address.
- **Custom / multiple IPs:** comma-separated IPv4/IPv6 literals, including existing `HOST` values. `0.0.0.0` means all IPv4 interfaces; prefer a specific LAN IP. Do not combine a wildcard with overlapping addresses on the same port.
- **Enable HTTPS:** requires readable certificate-chain PEM and private-key PEM files. File pickers store paths, never certificate/private-key contents.
- Saving preserves existing environment values, including tunnel hostname and custom keys. It validates addresses, port ranges, and TLS file paths, writes the settings file with mode 0600, and retains the existing relaunch-on-save behavior.

The changes apply to the MCP server, not the separate Playwright backend/proxy.

## Server configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `HOST` | `127.0.0.1` | One or more bind addresses, separated by commas |
| `PORT` | `3000` | Integer from 1 through 65535 |
| `TLS_ENABLED` | `false` | `true` / `1` enables HTTPS; `false` / `0` disables it. Unknown values are rejected by the Node server. |
| `TLS_CERT_PATH` | unset | PEM certificate chain path, required with TLS |
| `TLS_KEY_PATH` | unset | PEM private key path, required with TLS |

HTTPS replaces HTTP on this port; it does not expose a second plaintext listener. Invalid/missing/unreadable TLS material fails startup, never silently downgrades to HTTP. Bearer authentication remains unchanged. TLS minimum is 1.2.

Keep `MCP_API_KEY` set. TLS encrypts traffic; it does not replace authentication or network access restrictions. The existing server still allows unauthenticated operation if the key is absent.

## Certificates and clients

Use a certificate issued by a CA trusted by the VM. Its Subject Alternative Name must include the hostname clients use (`m4pro.drag.rocks`) and any address used by local health checks/tunnel origin connections. With multiple HOST values the first address is used for those connections; wildcard binds map to loopback. For a local CA, trust the CA on the VM (and the Mac where appropriate) before switching Hermes to HTTPS. Do not disable certificate verification or use `curl -k` as a permanent fix.

Protect private keys (mode 0600) and do not commit them. No certificates are generated or installed automatically. Renew certificate files and restart the server when deploying renewed material.

Once a built release is deliberately deployed and HTTPS is confirmed, change the VM's MCP URL to `https://m4pro.drag.rocks:3000/mcp`, retaining the existing Bearer secret. Do not switch the live client before the server is ready.

## Cloudflare compatibility

Quick tunnels use the configured scheme and first bind address. For TLS, the certificate file is supplied as the origin CA pool; it must provide the trust material Cloudflare needs, and the origin address must match its SAN. Never turn off origin certificate verification. Named tunnels retain their dashboard-managed ingress; update that ingress's scheme/address/CA settings separately. This workflow was source-typechecked, not exercised against a live tunnel.

## Verification

Run `npm test` for the Node test suite, `./node_modules/.bin/tsc --noEmit` for source type checking, and typecheck the Swift app with its macOS 13 deployment target. These checks do not build or install the application.

The network tests create temporary test-only certificates and real ephemeral HTTP/HTTPS listeners. They cover authentication, trusted and untrusted certificates, missing TLS files, invalid configuration, and listener rollback after a bind conflict. They do not modify the running helper or real credentials.

The Settings interface still requires a future built-app visual smoke test for layout, file pickers, saved values, relaunch, and native permission behavior. Do not treat source typechecking as that smoke test.
