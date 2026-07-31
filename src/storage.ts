// Off-chain storage for milestone proof docs. Only the CID goes on-chain (submitProof).
export interface IpfsClient {
  add: (content: string | Uint8Array, filename?: string) => Promise<string>;
  cat: (cid: string) => Promise<string>;
  addJSON: (data: unknown) => Promise<string>;
  catJSON: <T = unknown>(cid: string) => Promise<T>;
  gatewayUrl: (cid: string) => string;
}

// Connects to a local Kubo daemon's HTTP API (defaults match `ipfs daemon`).
export function connectIpfs(
  apiUrl = "http://127.0.0.1:5001",
  gatewayUrl = "http://127.0.0.1:8080",
): IpfsClient {
  async function add(
    content: string | Uint8Array,
    filename = "file",
  ): Promise<string> {
    const form = new FormData();
    form.append("file", new Blob([content]), filename);

    const res = await fetch(`${apiUrl}/api/v0/add`, {
      method: "POST",
      body: form,
    });
    if (!res.ok) {
      throw new Error(`IPFS add failed: ${res.status} ${await res.text()}`);
    }

    const { Hash: cid } = (await res.json()) as { Hash: string }; // Kubo calls the CID "Hash"
    return cid;
  }

  async function cat(cid: string): Promise<string> {
    const res = await fetch(`${apiUrl}/api/v0/cat?arg=${cid}`, {
      method: "POST",
    });
    if (!res.ok) {
      throw new Error(`IPFS cat failed: ${res.status} ${await res.text()}`);
    }
    return res.text();
  }

  async function addJSON(data: unknown): Promise<string> {
    return add(JSON.stringify(data), "data.json");
  }

  async function catJSON<T = unknown>(cid: string): Promise<T> {
    return JSON.parse(await cat(cid)) as T;
  }

  function gatewayUrlFor(cid: string): string {
    return `${gatewayUrl}/ipfs/${cid}`;
  }

  return { add, cat, addJSON, catJSON, gatewayUrl: gatewayUrlFor };
}
