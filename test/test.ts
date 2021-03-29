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

    // Deploy contracts
    const EtheremonToken = await ethers.getContractFactory("EtheremonToken");
    oldToken = await EtheremonToken.deploy(
      owner.getAddress(),
      account1.getAddress(),
      account2.getAddress(),
      account3.getAddress()
    );
    await oldToken.deployed();

    const EthermonToken = await ethers.getContractFactory("EthermonToken");
    newToken = await EthermonToken.deploy();
    await newToken.deployed();

    const Convertor = await ethers.getContractFactory(
      "contracts/TokenConvertor.sol:TokenConvertor"
    );
    convertor = await Convertor.deploy();

    await convertor.deployed();

    // Initiate addresses
    ownerAdd = await owner.getAddress();
    oldTokenAdd = oldToken.address;
    newTokenAdd = newToken.address;
    convertorAdd = convertor.address;

    await convertor.setAddress(oldTokenAdd, newTokenAdd);

    // Initiate token
    await newToken.transfer(
      convertor.address,
      BN.from(8000000).mul(newDecimal).toString()
    );
    await oldToken.transfer(
      convertor.address,
      BN.from(400000).mul(decimal).toString()
    );
  });

  it("Contracts deployed successfully", async function () {
    expect(await oldToken.name()).to.equal("EtheremonToken");
    expect(await newToken.name()).to.equal("EthermonToken");
    expect(await oldToken.balanceOf(account1.getAddress())).to.eq(
      BN.from("5000000").mul(decimal)
    );
    expect(await newToken.balanceOf(convertorAdd)).to.eq(
      BN.from(8000000).mul(newDecimal)
    );
    expect(await oldToken.balanceOf(convertorAdd)).to.eq(
      BN.from(400000).mul(decimal)
    );
  });

  it("Test New - Old Token Convertion succeed", async function () {
    const oldBalance: BN = await oldToken.balanceOf(ownerAdd);
    const newBalance: BN = await newToken.balanceOf(ownerAdd);
    const amount: BN = BN.from(100).mul(newDecimal);
    await newToken.transferAndCall(convertorAdd, amount, []);
    expect(await oldToken.balanceOf(ownerAdd)).to.eq(
      oldBalance.add(amount.div(20).div(newDecimal).mul(decimal))
    );
    expect(await newToken.balanceOf(ownerAdd)).to.eq(newBalance.sub(amount));
  });

  it("Test Old - New Token Convertion succeed", async function () {
    const oldBalance: BN = await oldToken.balanceOf(ownerAdd);
    const newBalance: BN = await newToken.balanceOf(ownerAdd);
    const amount: BN = BN.from(100).mul(decimal);
    await oldToken.approveAndCall(convertor.address, amount, []);
    expect(await oldToken.balanceOf(ownerAdd)).to.eq(oldBalance.sub(amount));
    expect(await newToken.balanceOf(ownerAdd)).to.eq(
      newBalance.add(amount.mul(20).div(decimal).mul(newDecimal))
    );
  });

  it("Disallow upgradable revert", async function () {
    await convertor.setUpgradable(false);
    const amount: BN = BN.from(100).mul(decimal);
    await expect(oldToken.approveAndCall(convertor.address, amount, [])).to.be
      .reverted;
  });

  it("Disallow downgradable revert", async function () {
    await convertor.setDowngradable(false);
    const amount: BN = BN.from(100).mul(decimal);
    await expect(newToken.transferAndCall(convertorAdd, amount, [])).to.be
      .reverted;
  });

  it("Call upgrading convertion function directly will revert", async function () {
    const amount: BN = BN.from(100).mul(decimal);
    await expect(
      convertor.convertToOld(amount, account1.getAddress())
    ).to.be.revertedWith("Must be called from New Token Contract");
  });

  it("Call downgrading convertion function directly will revert", async function () {
    const amount: BN = BN.from(100).mul(decimal);
    await expect(
      convertor.receiveApproval(account1.getAddress(), amount, oldTokenAdd, [])
    ).to.be.revertedWith("Must be called from Old Token Contract");
  });
});
