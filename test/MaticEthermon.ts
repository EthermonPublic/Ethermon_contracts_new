import { ethers } from "hardhat";
import { Signer, Contract, BigNumber as BN } from "ethers";
import { expect } from "chai";

describe("Test Token Converting", function () {
  let owner: Signer, account1: Signer, account2: Signer, account3: Signer;
  let oldToken: Contract, newToken: Contract, convertor: Contract;

  let ownerAdd, oldTokenAdd, newTokenAdd, convertorAdd;

  const decimal: BN = BN.from(10).pow(BN.from(8));
  const newDecimal: BN = BN.from(10).pow(BN.from(18));

  beforeEach(async function () {
    [owner, account1, account2, account3] = await ethers.getSigners();

    const EthermonToken = await ethers.getContractFactory("EthermonTokenMatic");
    newToken = await EthermonToken.deploy(
      "Ethermon",
      "EMON",
      18,
      account3.getAddress()
    );
    await newToken.deployed();
  });

  it("Contracts deployed successfully", async function () {
    expect(await newToken.name()).to.equal("Ethermon");
  });
});
