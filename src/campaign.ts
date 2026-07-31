import { parseEther, type Address, type PublicClient, type WalletClient } from "viem";
import { loadArtifact } from "./chain.ts";

const factoryArtifact = loadArtifact("CampaignFactory");
const campaignArtifact = loadArtifact("CrowdfundingCampaign");

export interface Milestone {
  description: string;
  bps: number;
  proofHash: string;
  submitted: boolean;
  approved: boolean;
  released: boolean;
}

export interface CampaignSummary {
  founder: Address;
  goalUsd: bigint;
  deadline: bigint;
  totalContributedWei: bigint;
  totalContributedUsd: bigint;
  isFunded: boolean;
  hasEnded: boolean;
  milestones: Milestone[];
}

// Deploys a CampaignFactory pointed at the given ETH/USD price feed.
export async function deployFactory(
  publicClient: PublicClient,
  wallet: WalletClient,
  priceFeed: Address,
): Promise<Address> {
  const hash = await wallet.deployContract({
    abi: factoryArtifact.abi,
    bytecode: factoryArtifact.bytecode,
    args: [priceFeed],
    chain: wallet.chain,
    account: wallet.account!,
  });
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  if (!receipt.contractAddress) throw new Error("Factory deployment did not return an address");
  return receipt.contractAddress;
}

export interface CreateCampaignArgs {
  goalUsd: bigint; // whole USD (e.g. 10_000n) — the factory scales this by 1e8 itself
  durationDays: bigint;
  milestoneDescriptions: string[];
  milestonePercent: number[];
}

// Creates a new campaign via the factory, returning its deployed address.
export async function createCampaign(
  publicClient: PublicClient,
  wallet: WalletClient,
  factoryAddress: Address,
  args: CreateCampaignArgs,
): Promise<Address> {
  const hash = await wallet.writeContract({
    address: factoryAddress,
    abi: factoryArtifact.abi,
    functionName: "createCampaign",
    args: [args.goalUsd, args.durationDays, args.milestoneDescriptions, args.milestonePercent],
    chain: wallet.chain,
    account: wallet.account!,
  });
  const receipt = await publicClient.waitForTransactionReceipt({ hash });

  const log = receipt.logs.find(
    (l) => l.address.toLowerCase() === factoryAddress.toLowerCase(),
  );
  if (!log) throw new Error("CampaignCreated event not found in receipt");

  // CampaignCreated(address indexed campaignAddress, ...) — address is the first indexed topic.
  return `0x${log.topics[1]!.slice(-40)}` as Address;
}

export async function listCampaigns(
  publicClient: PublicClient,
  factoryAddress: Address,
): Promise<Address[]> {
  return publicClient.readContract({
    address: factoryAddress,
    abi: factoryArtifact.abi,
    functionName: "getAllCampaigns",
  }) as Promise<Address[]>;
}

export async function contribute(
  wallet: WalletClient,
  publicClient: PublicClient,
  campaignAddress: Address,
  ethAmount: string,
): Promise<`0x${string}`> {
  const hash = await wallet.writeContract({
    address: campaignAddress,
    abi: campaignArtifact.abi,
    functionName: "contribute",
    value: parseEther(ethAmount),
    chain: wallet.chain,
    account: wallet.account!,
  });
  await publicClient.waitForTransactionReceipt({ hash });
  return hash;
}

export async function submitProof(
  wallet: WalletClient,
  publicClient: PublicClient,
  campaignAddress: Address,
  milestoneId: number,
  proofHash: string,
): Promise<`0x${string}`> {
  const hash = await wallet.writeContract({
    address: campaignAddress,
    abi: campaignArtifact.abi,
    functionName: "submitProof",
    args: [BigInt(milestoneId), proofHash],
    chain: wallet.chain,
    account: wallet.account!,
  });
  await publicClient.waitForTransactionReceipt({ hash });
  return hash;
}

export async function releaseInitialFunds(
  wallet: WalletClient,
  publicClient: PublicClient,
  campaignAddress: Address,
): Promise<`0x${string}`> {
  const hash = await wallet.writeContract({
    address: campaignAddress,
    abi: campaignArtifact.abi,
    functionName: "releaseInitialFunds",
    chain: wallet.chain,
    account: wallet.account!,
  });
  await publicClient.waitForTransactionReceipt({ hash });
  return hash;
}

export async function claimRefund(
  wallet: WalletClient,
  publicClient: PublicClient,
  campaignAddress: Address,
): Promise<`0x${string}`> {
  const hash = await wallet.writeContract({
    address: campaignAddress,
    abi: campaignArtifact.abi,
    functionName: "claimRefund",
    chain: wallet.chain,
    account: wallet.account!,
  });
  await publicClient.waitForTransactionReceipt({ hash });
  return hash;
}

export async function getCampaignSummary(
  publicClient: PublicClient,
  campaignAddress: Address,
): Promise<CampaignSummary> {
  const base = { address: campaignAddress, abi: campaignArtifact.abi } as const;

  const [founder, goalUsd, deadline, totalContributedWei, totalContributedUsd, isFunded, hasEnded, milestoneCount] =
    await Promise.all([
      publicClient.readContract({ ...base, functionName: "founder" }) as Promise<Address>,
      publicClient.readContract({ ...base, functionName: "goalUsd" }) as Promise<bigint>,
      publicClient.readContract({ ...base, functionName: "deadline" }) as Promise<bigint>,
      publicClient.readContract({ ...base, functionName: "totalContributedWei" }) as Promise<bigint>,
      publicClient.readContract({ ...base, functionName: "totalContributedUsd" }) as Promise<bigint>,
      publicClient.readContract({ ...base, functionName: "isFunded" }) as Promise<boolean>,
      publicClient.readContract({ ...base, functionName: "hasEnded" }) as Promise<boolean>,
      publicClient.readContract({ ...base, functionName: "getMilestoneCount" }) as Promise<bigint>,
    ]);

  const milestones = await Promise.all(
    Array.from({ length: Number(milestoneCount) }, (_, i) =>
      publicClient.readContract({ ...base, functionName: "milestones", args: [BigInt(i)] }) as Promise<
        [string, number, string, boolean, boolean, boolean]
      >,
    ),
  ).then((rows) =>
    rows.map(([description, bps, proofHash, submitted, approved, released]) => ({
      description,
      bps,
      proofHash,
      submitted,
      approved,
      released,
    })),
  );

  return { founder, goalUsd, deadline, totalContributedWei, totalContributedUsd, isFunded, hasEnded, milestones };
}
