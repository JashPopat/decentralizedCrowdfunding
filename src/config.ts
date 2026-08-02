import { readFileSync } from "node:fs";
import { parse } from "yaml";

export interface AccountConfig {
  name: string;
  privateKey: `0x${string}`;
}

export interface AppConfig {
  rpcUrl: string;
  accounts: AccountConfig[];
}

// Loads and validates config.yaml (RPC URL + named accounts), default path is repo root.
export function loadConfig(path = "config.yaml"): AppConfig {
  const raw = parse(readFileSync(path, "utf-8"));

  if (typeof raw?.rpcUrl !== "string") {
    throw new Error("config.yaml: missing or invalid rpcUrl");
  }
  if (!Array.isArray(raw?.accounts) || raw.accounts.length === 0) {
    throw new Error("config.yaml: accounts must be a non-empty list");
  }
  for (const acc of raw.accounts) {
    if (typeof acc?.name !== "string" || typeof acc?.privateKey !== "string") {
      throw new Error(`config.yaml: invalid account entry ${JSON.stringify(acc)}`);
    }
  }

  return raw as AppConfig;
}

// Finds an account by name, throwing with the valid options if not found.
export function findAccount(config: AppConfig, name: string): AccountConfig {
  const account = config.accounts.find((a) => a.name === name);
  if (!account) {
    const names = config.accounts.map((a) => a.name).join(", ");
    throw new Error(`No account named "${name}". Known accounts: ${names}`);
  }
  return account;
}
