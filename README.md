# decentralised crowdfunding

**status:**

- foundry setup complete
- solidity contracts in contracts/
- ts CLI in src/
- off-chain storage placeholder in data/

**setup:**

1. clone repo
2. initialise foundry dependencies:
   git submodule update --init --recursive
3. npm install
4. forge build
5. npm run build


Do not commit generated files e.g.
- out/
- cache/
etc

**notes:**
contract expects a price feed address which implements latestRoundData().

MockEthUSDPriceFee.sol is currently a placeholder for a local mock oracle
