// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
require("dotenv").config();

async function main() {

  const stakingcontract = await hre.ethers.deployContract("StakingContract", ["0x694AA1769357215DE4FAC081bf1f309aDC325306"]);
  const stakingcontractbytes = await hre.ethers.deployContract("StakingContractBytes", ["0x694AA1769357215DE4FAC081bf1f309aDC325306"]);
  await stakingcontract.waitForDeployment();
  await stakingcontractbytes.waitForDeployment();

  console.log(`Staking contract deployed to ${stakingcontract.target}`);
  console.log(`Staking contract bytes deployed to ${stakingcontractbytes.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
