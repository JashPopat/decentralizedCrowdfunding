import { select, input, number, confirm } from "@inquirer/prompts";
import type { AppConfig } from "./config.ts";
import type { CampaignSummary } from "./campaign.ts";

export async function askAccountName(config: AppConfig): Promise<string> {
  return select({
    message: "Which account are you acting as?",
    choices: config.accounts.map((a) => ({ name: a.name, value: a.name })),
  });
}

export type MenuAction =
  | "deployFactory"
  | "createCampaign"
  | "listCampaigns"
  | "viewCampaign"
  | "contribute"
  | "submitProof"
  | "releaseInitialFunds"
  | "voteOnMilestone"
  | "releaseMilestone"
  | "rejectExpiredMilestone"
  | "claimRefund"
  | "claimProRataRefund"
  | "switchAccount"
  | "quit";

export async function askMenuAction(): Promise<MenuAction> {
  return select({
    message: "What do you want to do?",
    choices: [
      { name: "Deploy a new factory", value: "deployFactory" },
      { name: "Create a campaign", value: "createCampaign" },
      { name: "List campaigns on a factory", value: "listCampaigns" },
      { name: "View a campaign's status", value: "viewCampaign" },
      { name: "Contribute to a campaign", value: "contribute" },
      { name: "Submit milestone proof (founder)", value: "submitProof" },
      { name: "Release initial milestone funds (founder)", value: "releaseInitialFunds" },
      { name: "Vote to approve a milestone (backer)", value: "voteOnMilestone" },
      { name: "Release an approved milestone (founder)", value: "releaseMilestone" },
      { name: "Reject an expired milestone vote", value: "rejectExpiredMilestone" },
      { name: "Claim refund (failed campaign)", value: "claimRefund" },
      { name: "Claim pro-rata refund (failed milestone)", value: "claimProRataRefund" },
      { name: "Switch account", value: "switchAccount" },
      { name: "Quit", value: "quit" },
    ],
  });
}

export async function askAddress(message: string): Promise<`0x${string}`> {
  const value = await input({
    message,
    validate: (v) => /^0x[0-9a-fA-F]{40}$/.test(v) || "Enter a valid 0x address",
  });
  return value as `0x${string}`;
}

export async function askCreateCampaign() {
  const goalUsd = await number({ message: "Funding goal (whole USD)", default: 10_000 });
  const durationDays = await number({ message: "Duration (days)", default: 30 });

  const milestoneDescriptions: string[] = [];
  const milestonePercent: number[] = [];
  let remaining = 100;
  do {
    const description = await input({ message: `Milestone ${milestoneDescriptions.length + 1} description` });
    const percent = await number({
      message: `Milestone ${milestoneDescriptions.length + 1} percent of goal (remaining: ${remaining}%)`,
      default: remaining,
    });
    milestoneDescriptions.push(description);
    milestonePercent.push(percent!);
    remaining -= percent!;
  } while (remaining > 0 && (await confirm({ message: "Add another milestone?", default: false })));

  return {
    goalUsd: BigInt(Math.round(goalUsd!)),
    durationDays: BigInt(Math.round(durationDays!)),
    milestoneDescriptions,
    milestonePercent,
  };
}

export async function askEthAmount(message = "Amount to contribute (ETH)"): Promise<string> {
  return input({
    message,
    validate: (v) => !Number.isNaN(Number(v)) && Number(v) > 0 || "Enter a positive number",
  });
}

export async function askMilestoneId(): Promise<number> {
  const value = await number({ message: "Milestone index (0-based)", default: 0 });
  return value!;
}

export async function askProofFilePath(): Promise<string> {
  return input({ message: "Path to the proof document to upload to IPFS" });
}

export function printSummary(address: string, summary: CampaignSummary): void {
  console.log(`\nCampaign ${address}`);
  console.log(`  founder: ${summary.founder}`);
  console.log(`  goal: $${(summary.goalUsd / 100_000_000n).toString()}`);
  console.log(`  deadline: ${new Date(Number(summary.deadline) * 1000).toISOString()}`);
  console.log(`  raised: $${(summary.totalContributedUsd / 100_000_000n).toString()} (${summary.totalContributedWei} wei)`);
  console.log(`  funded: ${summary.isFunded}, ended: ${summary.hasEnded}`);
  console.log("  milestones:");
  summary.milestones.forEach((m, i) => {
    const voteDeadline = m.voteDeadline > 0n ? new Date(Number(m.voteDeadline) * 1000).toISOString() : "-";
    console.log(
      `    [${i}] ${m.description} (${m.bps / 100}%) submitted=${m.submitted} approved=${m.approved} rejected=${m.rejected} released=${m.released} voteDeadline=${voteDeadline}`,
    );
  });
  console.log("");
}

export function printError(err: unknown): void {
  console.error("Error:", err instanceof Error ? err.message : err);
}
