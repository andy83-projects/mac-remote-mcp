import http from "node:http";
import https from "node:https";
import { readFileSync } from "node:fs";
import type { Application } from "express";

export interface NetworkOptions {
  port: number;
  hosts: string[];
  tlsEnabled: boolean;
  tlsCertPath?: string;
  tlsKeyPath?: string;
}

export function readNetworkOptions(env: Record<string, string | undefined>): NetworkOptions {
  const toggle = env.TLS_ENABLED?.trim().toLowerCase() || "false";
  if (!["true", "false", "1", "0"].includes(toggle)) throw new Error("TLS_ENABLED must be true or false");
  const tlsEnabled = toggle === "true" || toggle === "1";
  const port = Number(env.PORT || "3000");
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error("PORT must be an integer from 1 to 65535");
  const hosts = [...new Set((env.HOST || "127.0.0.1").split(",").map(h => h.trim()).filter(Boolean))];
  if (!hosts.length) throw new Error("HOST must contain at least one address");
  const tlsCertPath = env.TLS_CERT_PATH?.trim() || undefined;
  const tlsKeyPath = env.TLS_KEY_PATH?.trim() || undefined;
  if (tlsEnabled && (!tlsCertPath || !tlsKeyPath)) {
    throw new Error("TLS_CERT_PATH and TLS_KEY_PATH are required when TLS_ENABLED is true");
  }
  return {
    port, hosts,
    tlsEnabled, tlsCertPath, tlsKeyPath,
  };
}

export function createNetworkServer(app: Application, options: NetworkOptions): http.Server | https.Server {
  if (!options.tlsEnabled) return http.createServer(app);
  if (!options.tlsCertPath || !options.tlsKeyPath) {
    throw new Error("TLS_CERT_PATH and TLS_KEY_PATH are required when TLS_ENABLED is true");
  }
  return https.createServer({
    cert: readFileSync(options.tlsCertPath),
    key: readFileSync(options.tlsKeyPath),
    minVersion: "TLSv1.2",
  }, app);
}

// Start serially so a failed bind can close all previously started listeners.
export async function startNetworkServers(app: Application, options: NetworkOptions): Promise<(http.Server | https.Server)[]> {
  const servers: (http.Server | https.Server)[] = [];
  try {
    for (const host of options.hosts) {
      const server = createNetworkServer(app, options);
      servers.push(server);
      await new Promise<void>((resolve, reject) => {
        server.once("error", reject);
        server.listen(options.port, host, () => {
          server.removeListener("error", reject);
          resolve();
        });
      });
      const scheme = options.tlsEnabled ? "https" : "http";
      const address = host.includes(":") ? `[${host}]` : host;
      console.error(`mac-remote-mcp running on ${scheme}://${address}:${(server.address() as import("node:net").AddressInfo).port}/mcp`);
    }
    return servers;
  } catch (error) {
    await Promise.all(servers.filter(server => server.listening).map(server => new Promise<void>(resolve => server.close(() => resolve()))));
    throw error;
  }
}
