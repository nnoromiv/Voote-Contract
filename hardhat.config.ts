import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.25",
  networks : {
    sepolia :{
      url: process.env.RPC_URL!,
      accounts: [process.env.PRIVATE_KEY!]
    }
  },
  etherscan : {
    apiKey : process.env.POLYGON_SCAN_API_KEY!
  }
};

export default config;
