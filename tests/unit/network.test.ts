import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import express from "express";
import http from "node:http";
import https from "node:https";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import type { AddressInfo } from "node:net";
import * as network from "../../src/network.js";
import { bearerAuth } from "../../src/auth.js";

let directory: string;
let certPath: string;
let keyPath: string;
const listeners: (http.Server | https.Server)[] = [];
beforeAll(() => {
  directory = mkdtempSync(join(tmpdir(), "mac-mcp-tls-"));
  certPath = join(directory, "cert.pem"); keyPath = join(directory, "key.pem");
  execFileSync("openssl", ["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", keyPath,
    "-out", certPath, "-days", "1", "-subj", "/CN=127.0.0.1", "-addext", "subjectAltName=IP:127.0.0.1"], { stdio: "ignore" });
});
afterEach(async () => {
  vi.unstubAllEnvs();
  await Promise.all(listeners.splice(0).map(server => new Promise<void>((resolve, reject) => {
    server.closeAllConnections(); server.close(error => error ? reject(error) : resolve());
  })));
});
afterAll(() => rmSync(directory, { recursive: true, force: true }));

function request(server: http.Server | https.Server, path: string, tls = false, token?: string, trust = true): Promise<number> {
  const port = (server.address() as AddressInfo).port;
  return new Promise((resolve, reject) => {
    const options = { hostname: "127.0.0.1", port, path,
      ...(tls && trust ? { ca: readFileSync(certPath) } : {}),
      headers: token ? { Authorization: `Bearer ${token}` } : {} };
    const req = (tls ? https : http).get(options, res => { res.resume(); res.on("end", () => resolve(res.statusCode!)); });
    req.on("error", reject);
  });
}

describe("network configuration", () => {
  it("defaults to HTTP on loopback", () => {
    expect(network.readNetworkOptions({})).toMatchObject({ tlsEnabled: false, port: 3000, hosts: ["127.0.0.1"] });
  });
  it("reads TLS files and deduplicates interface addresses", () => {
    expect(network.readNetworkOptions({ TLS_ENABLED: "true", TLS_CERT_PATH: certPath, TLS_KEY_PATH: keyPath,
      HOST: " 127.0.0.1,10.0.0.53,127.0.0.1 ", PORT: "8443" })).toMatchObject({
      tlsEnabled: true, tlsCertPath: certPath, tlsKeyPath: keyPath, port: 8443, hosts: ["127.0.0.1", "10.0.0.53"] });
  });
  it("rejects missing TLS files", () => {
    expect(() => network.readNetworkOptions({ TLS_ENABLED: "true" })).toThrow(/required/);
  });
  it.each(["0", "65536", "-1", "3x", "3.5"])("rejects invalid port %s", PORT => {
    expect(() => network.readNetworkOptions({ PORT })).toThrow(/PORT/);
  });
  it("rejects an empty interface list", () => {
    expect(() => network.readNetworkOptions({ HOST: " , " })).toThrow(/HOST/);
  });
  it("rejects unknown TLS toggles rather than silently serving HTTP", () => {
    expect(() => network.readNetworkOptions({ TLS_ENABLED: "treu" })).toThrow(/TLS_ENABLED/);
  });
  it("never falls back to HTTP for unreadable or invalid TLS material", () => {
    expect(() => network.createNetworkServer(express(), { port: 0, hosts: ["127.0.0.1"], tlsEnabled: true,
      tlsCertPath: "/nonexistent/cert", tlsKeyPath: keyPath })).toThrow();
  });
});

describe("real HTTP/HTTPS listeners", () => {
  it("serves HTTP with TLS disabled", async () => {
    const app = express(); app.get("/health", (_req, res) => res.sendStatus(200));
    const servers = await network.startNetworkServers(app, { port: 0, hosts: ["127.0.0.1"], tlsEnabled: false });
    listeners.push(...servers); expect(await request(servers[0], "/health")).toBe(200);
  });
  it("serves trusted HTTPS and keeps Bearer authentication", async () => {
    vi.stubEnv("MCP_API_KEY", "test-only-not-a-real-key");
    const app = express(); app.use(bearerAuth);
    app.get("/health", (_req, res) => res.sendStatus(200));
    app.get("/mcp", (_req, res) => res.sendStatus(200));
    const servers = await network.startNetworkServers(app, { port: 0, hosts: ["127.0.0.1"], tlsEnabled: true,
      tlsCertPath: certPath, tlsKeyPath: keyPath });
    listeners.push(...servers);
    expect(await request(servers[0], "/health", true)).toBe(200);
    expect(await request(servers[0], "/mcp", true)).toBe(401);
    expect(await request(servers[0], "/mcp", true, "wrong-key")).toBe(403);
    expect(await request(servers[0], "/mcp", true, "test-only-not-a-real-key")).toBe(200);
    await expect(request(servers[0], "/health", true, undefined, false)).rejects.toThrow();
  });
  it("closes earlier listeners if a later interface fails", async () => {
    const app = express(); const original = http.createServer();
    await new Promise<void>(resolve => original.listen(0, "127.0.0.1", resolve)); listeners.push(original);
    const port = (original.address() as AddressInfo).port;
    await expect(network.startNetworkServers(app, { port, hosts: ["::1", "127.0.0.1"], tlsEnabled: false })).rejects.toThrow();
    const probe = http.createServer(); listeners.push(probe);
    await new Promise<void>((resolve, reject) => { probe.once("error", reject); probe.listen(port, "::1", resolve); });
  });
});
