import { run, ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const AaveConn = await ethers.getContractFactory("ConnectAave");
  const aaveConn = await AaveConn.deploy();

  console.log("Greeter deployed to:", aaveConn.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
