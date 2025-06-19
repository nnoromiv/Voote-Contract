import { ethers } from "hardhat";

async function main() {
  const Voote = await ethers.getContractFactory("Voote");

  const voote = await Voote.deploy();

  await voote.waitForDeployment();

  console.log(`✅ Contract deployed to: ${voote.target}`);
}

main().catch((error) => {
  console.error("❌ Deployment failed:", error);
  process.exitCode = 1;
});
