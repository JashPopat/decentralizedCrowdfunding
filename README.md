# Decentralized Crowdfunding

A milestone-based, on-chain crowdfunding platform. Backers contribute ETH toward a USD-denominated goal (priced via a Chainlink-style oracle), and founders can only draw funds as milestones are submitted, backed by IPFS-hosted proof, and approved through USD-weighted voting by backers. If a milestone is rejected or the goal is never reached, backers can claim a refund.

The repo has two parts:

- **`contracts/`** — Solidity smart contracts (Foundry), unit-tested with `forge test`
- **`src/`** — A TypeScript CLI (built on [viem](https://viem.sh)) for deploying campaigns and driving the full lifecycle: contribute, submit proof, vote, release funds, refund

## How it works

1. A **`CampaignFactory`** is deployed once, pointed at a price feed. It deploys new `CrowdfundingCampaign` instances on demand.
2. Anyone can call `createCampaign` on the factory with a USD funding goal, a duration, and an ordered list of milestones (each a description + % of the goal in basis points, summing to 100%).
3. Backers `contribute()` ETH. Each contribution is converted to USD at current oracle price (with a small markup, see [Notes](#notes)) and tracked per-backer.
4. Once the goal is met (`isFunded()`), the founder can release the first milestone's share immediately via `releaseInitialFunds()`.
5. For every later milestone, the founder must `submitProof()` (a hash/CID pointing at proof uploaded to IPFS). This opens a 3-day voting window.
6. Backers `voteOnMilestone()`, weighted by their USD contribution. A milestone is approved once votes exceed 50% of total USD raised, and the founder can then `releaseMilestone()`.
7. If a milestone's voting window closes without approval, anyone can call `rejectExpiredMilestone()`. This marks the campaign failed and snapshots the remaining balance for pro-rata refunds via `claimProRataRefund()`.
8. If the campaign never reaches its goal by the deadline, backers call `claimRefund()` for a full refund of what they contributed.

## Project structure

```
contracts/
  CampaignFactory.sol           # deploys & tracks campaigns
  CrowdfundingCampaign.sol      # per-campaign funding, milestones, voting, refunds
  interfaces/AggregatorV3Interface.sol
  mocks/MockEthUsdPriceFeed.sol # local stand-in for a Chainlink ETH/USD feed
test/
  CampaignFactory.t.sol
  CrowdfundingCampaign.t.sol
src/
  index.ts     # CLI entrypoint / main menu loop
  chain.ts     # viem public client + wallet setup
  campaign.ts  # contract-calling functions (deploy, contribute, vote, release, refund...)
  storage.ts   # IPFS (Kubo HTTP API) client for milestone proof uploads
  config.ts    # loads config.yaml (RPC URL + named local accounts)
  ui.ts        # inquirer prompts for the interactive CLI
config.yaml    # local RPC URL + Anvil's well-known default test accounts
```

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `anvil`, `cast`)
- [Node.js](https://nodejs.org/) (v20+) and npm
- [IPFS (Kubo)](https://docs.ipfs.tech/install/command-line/) for the `ipfs daemon`
- If you're on Windows, run all of the above inside WSL

## Setup

```bash
git clone https://github.com/JashPopat/decentralizedCrowdfunding.git
cd decentralizedCrowdfunding

# pull in Foundry dependencies (forge-std etc.)
git submodule update --init --recursive

npm install
forge build
npm run build     # tsc --noEmit — type-checks the CLI, emits nothing
```

`out/` and `cache/` are Foundry build artifacts — don't commit them.

## Running the tests

```bash
forge test --summary
```

This runs the full contract test suite (contract creation/validation, contributions, milestone voting, releases, and refunds) and prints a pass/fail summary table.

## Running the CLI demo

The demo uses three terminals: one for the local chain, one for IPFS, and one to run the setup and the CLI itself. Every terminal below assumes WSL (adjust if you're already on Linux/macOS).

**Terminal 1 — local chain:**

```bash
wsl -d Ubuntu -u dev
anvil
```

Leave this running — it's your local Ethereum node, pre-funded with test accounts (the same ones referenced in `config.yaml`).

**Terminal 2 — local IPFS node:**

```bash
wsl -d Ubuntu -u dev
ipfs daemon
```

Wait for it to print `Daemon is ready.` This is what `submitProof` uploads milestone proof documents to.

**Terminal 3 — deploy the mock price feed:**

```bash
wsl -d Ubuntu -u dev
cd ~/projects/decentralizedCrowdfunding
forge build
forge create contracts/mocks/MockEthUsdPriceFeed.sol:MockEthUsdPriceFeed \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast --constructor-args 200000000000
```

This deploys a mock ETH/USD oracle (seeded at $2000/ETH, 8 decimals — `200000000000`) using Anvil's default account #0. Copy the deployed contract address — you'll need it for the `deployFactory` step in the CLI.

**Terminal 3 — run the CLI:**

```bash
npm start
```

This starts the interactive menu (`src/index.ts`). Typical walkthrough:

1. **Pick an account** — one of `founder`, `alice`, or `bob` from `config.yaml`
2. **`deployFactory`** — paste in the mock price feed address from the previous step
3. **`createCampaign`** — set a USD goal, duration, and milestones (description + % each, must sum to 100)
4. **`switchAccount`** to a backer (e.g. `alice`) and **`contribute`** ETH until the goal is met
5. Switch back to `founder`, **`releaseInitialFunds`** once funded
6. **`submitProof`** for the next milestone — this uploads a local file to IPFS and records the returned CID on-chain
7. Switch to backer accounts and **`voteOnMilestone`** until it crosses 50% of contributed USD
8. **`releaseMilestone`** as founder once approved
9. **`viewCampaign`** at any point to see the full on-chain summary; **`listCampaigns`** to see everything a factory has deployed

### Useful `cast` commands while demoing

Check a backer's ETH balance:

```bash
cast balance 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --rpc-url http://127.0.0.1:8545 --ether
```

Fast-forward the chain (e.g. to close a voting window or pass the campaign deadline — 90000s = 25h here):

```bash
cast rpc anvil_increaseTime 90000 --rpc-url http://127.0.0.1:8545
cast rpc anvil_mine --rpc-url http://127.0.0.1:8545
```

### Estimating gas cost in USD

```
Cost in ETH = gas used × gas price ÷ 1e18
```

Example, at the mock price of $2000/ETH:

```
128,540 gas × 1,000,000,000 wei/gas ÷ 1e18 = 0.00012854 ETH
0.00012854 ETH × $2000 ≈ $0.257 USD
```

## Notes

- The price feed passed into a campaign must implement `latestRoundData()` (Chainlink's `AggregatorV3Interface`). `MockEthUsdPriceFeed.sol` is a local stand-in for demos/tests; on a real network this would point at Chainlink's live ETH/USD feed.
- Contributions are converted to USD at a 98% rate (a 2% markup baked into `ethToUsd`) to offset gas costs instead of charging an explicit fee. This only applies at contribution time — refunds always return the exact ETH originally sent.
- `config.yaml` ships with Anvil's well-known default test account keys. These are public, funded automatically by `anvil`, and safe to commit — never reuse them beyond a local test chain.
