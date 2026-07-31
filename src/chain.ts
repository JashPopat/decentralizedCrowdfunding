import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import {
  createPublicClient,
  createWalletClient,
  http,
  type Address,
  type PublicClient,
  type WalletClient,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";

const __dirname = dirname(fileURLToPath(import.meta.url));

export interface ContractArtifact {
  abi: readonly unknown[];
  bytecode: `0x${string}`;
}

// Reads ABI + bytecode from the forge build output for a given contract name.
export function loadArtifact(contractName: string): ContractArtifact {
  const path = join(
    __dirname,
    "..",
    "out",
    `${contractName}.sol`,
    `${contractName}.json`,
  );
  const raw = JSON.parse(readFileSync(path, "utf-8"));
  return {
    abi: raw.abi,
    bytecode: raw.bytecode.object as `0x${string}`,
  };
}

export interface ChainClients {
  publicClient: PublicClient;
  walletFor: (privateKey: `0x${string}`) => WalletClient; // signs and sends as this key
  addressOf: (privateKey: `0x${string}`) => Address;
  getBalance: (address: Address) => Promise<bigint>;
}

// Connects to an EVM node over HTTP, e.g. "http://127.0.0.1:8545" for anvil.
export function connect(rpcUrl: string): ChainClients {
  const transport = http(rpcUrl);
  const publicClient = createPublicClient({ transport });

  function walletFor(privateKey: `0x${string}`): WalletClient {
    return createWalletClient({
      account: privateKeyToAccount(privateKey),
      transport,
    });
  }

  function addressOf(privateKey: `0x${string}`): Address {
    return privateKeyToAccount(privateKey).address;
  }

  async function getBalance(address: Address): Promise<bigint> {
    return publicClient.getBalance({ address });
  }

  return { publicClient, walletFor, addressOf, getBalance };
}
