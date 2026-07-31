import { readFileSync } from "node:fs";
import { connect } from "./chain.ts";
import { connectIpfs } from "./storage.ts";
import { loadConfig, findAccount } from "./config.ts";
import * as campaign from "./campaign.ts";
import * as ui from "./ui.ts";

async function main() {
  const config = loadConfig();
  const { publicClient, walletFor } = connect(config.rpcUrl);
  const ipfs = connectIpfs();

  let accountName = await ui.askAccountName(config);

  while (true) {
    const account = findAccount(config, accountName);
    const wallet = walletFor(account.privateKey);
    const action = await ui.askMenuAction();

    try {
      switch (action) {
        case "deployFactory": {
          const priceFeed = await ui.askAddress("ETH/USD price feed address");
          const address = await campaign.deployFactory(publicClient, wallet, priceFeed);
          console.log(`Factory deployed at ${address}`);
          break;
        }

        case "createCampaign": {
          const factoryAddress = await ui.askAddress("Factory address");
          const args = await ui.askCreateCampaign();
          const address = await campaign.createCampaign(publicClient, wallet, factoryAddress, args);
          console.log(`Campaign deployed at ${address}`);
          break;
        }

        case "listCampaigns": {
          const factoryAddress = await ui.askAddress("Factory address");
          const campaigns = await campaign.listCampaigns(publicClient, factoryAddress);
          console.log(campaigns.length ? campaigns.join("\n") : "(no campaigns yet)");
          break;
        }

        case "viewCampaign": {
          const campaignAddress = await ui.askAddress("Campaign address");
          const summary = await campaign.getCampaignSummary(publicClient, campaignAddress);
          ui.printSummary(campaignAddress, summary);
          break;
        }

        case "contribute": {
          const campaignAddress = await ui.askAddress("Campaign address");
          const amount = await ui.askEthAmount();
          const hash = await campaign.contribute(wallet, publicClient, campaignAddress, amount);
          console.log(`Contributed. tx: ${hash}`);
          break;
        }

        case "submitProof": {
          const campaignAddress = await ui.askAddress("Campaign address");
          const milestoneId = await ui.askMilestoneId();
          const filePath = await ui.askProofFilePath();
          const content = readFileSync(filePath);
          const cid = await ipfs.add(content, filePath);
          console.log(`Uploaded to IPFS: ${cid} (${ipfs.gatewayUrl(cid)})`);
          const hash = await campaign.submitProof(wallet, publicClient, campaignAddress, milestoneId, cid);
          console.log(`Proof submitted on-chain. tx: ${hash}`);
          break;
        }

        case "releaseInitialFunds": {
          const campaignAddress = await ui.askAddress("Campaign address");
          const hash = await campaign.releaseInitialFunds(wallet, publicClient, campaignAddress);
          console.log(`Released. tx: ${hash}`);
          break;
        }

        case "claimRefund": {
          const campaignAddress = await ui.askAddress("Campaign address");
          const hash = await campaign.claimRefund(wallet, publicClient, campaignAddress);
          console.log(`Refund claimed. tx: ${hash}`);
          break;
        }

        case "switchAccount": {
          accountName = await ui.askAccountName(config);
          break;
        }

        case "quit":
          return;
      }
    } catch (err) {
      ui.printError(err);
    }
  }
}

main().catch((err) => {
  ui.printError(err);
  process.exit(1);
});
