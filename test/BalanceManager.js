const { expect } = require("chai");
const { ethers } = require("hardhat");

const getSignature = async (signer, beneficiary, amount, nonce) => {
  let message = ethers.utils.solidityKeccak256(["address", "uint256", "uint256"], [beneficiary, amount, nonce]);
  let signature = await signer.signMessage(ethers.utils.arrayify(message));
  return signature;
};

describe("BalanceManager", function () {
  let balanceManager, nftl;

  const INIT_BALANCE = 10000;
  const DEPOSIT_AMOUNT = 500;
  const WITHDRAW_AMOUNT = 200;

  beforeEach(async () => {
    [deployer, maintainer, alice, bob] = await ethers.getSigners();

    // Deploy NFTL token
    const NFTL = await ethers.getContractFactory("MockERC20");
    nftl = await NFTL.deploy();

    // Deploy BalanceManager
    const BalanceManager = await ethers.getContractFactory("BalanceManager");
    balanceManager = await upgrades.deployProxy(BalanceManager, [nftl.address, maintainer.address]);

    // Mint NFTL tokens to users
    nftl.mint(alice.address, INIT_BALANCE);
    nftl.mint(bob.address, INIT_BALANCE);
  });

  describe("deposit", function () {
    it("should be able to deposit NFTL tokens", async () => {
      expect(await nftl.balanceOf(alice.address)).to.equal(INIT_BALANCE);

      // deposit
      await nftl.connect(alice).approve(balanceManager.address, DEPOSIT_AMOUNT);
      await balanceManager.connect(alice).deposit(DEPOSIT_AMOUNT);

      expect(await nftl.balanceOf(alice.address)).to.equal(INIT_BALANCE - DEPOSIT_AMOUNT);
    });
  });

  describe("withdraw", function () {
    beforeEach(async () => {
      // deposit
      await nftl.connect(alice).approve(balanceManager.address, DEPOSIT_AMOUNT);
      await balanceManager.connect(alice).deposit(DEPOSIT_AMOUNT);

      await nftl.connect(bob).approve(balanceManager.address, DEPOSIT_AMOUNT);
      await balanceManager.connect(bob).deposit(DEPOSIT_AMOUNT);
    });

    it("should be able to withdraw NFTL tokens", async () => {
      // withdraw
      let nonceForAlice = await balanceManager.nonce(alice.address);
      let signatureForAlice = await getSignature(maintainer, alice.address, WITHDRAW_AMOUNT, nonceForAlice);
      await balanceManager
        .connect(maintainer)
        .withdraw(alice.address, WITHDRAW_AMOUNT, nonceForAlice, signatureForAlice);

      expect(await nftl.balanceOf(alice.address)).to.equal(INIT_BALANCE - DEPOSIT_AMOUNT + WITHDRAW_AMOUNT);
    });

    it("revert if msg.sender is not a maintainer", async () => {
      // withdraw
      let nonceForAlice = await balanceManager.nonce(alice.address);
      let signatureForAlice = await getSignature(maintainer, alice.address, WITHDRAW_AMOUNT, nonceForAlice);

      await expect(
        balanceManager.connect(alice).withdraw(alice.address, WITHDRAW_AMOUNT, nonceForAlice, signatureForAlice),
      ).to.be.revertedWith("only maintainer");
    });

    it("revert if the nonce is invalid", async () => {
      // withdraw
      let nonceForAlice = await balanceManager.nonce(alice.address);
      let signatureForAlice = await getSignature(maintainer, alice.address, WITHDRAW_AMOUNT, nonceForAlice + 1);

      await expect(
        balanceManager
          .connect(maintainer)
          .withdraw(alice.address, WITHDRAW_AMOUNT, nonceForAlice + 1, signatureForAlice),
      ).to.be.revertedWith("mismatched nonce");
    });

    it("revert if the signature is used twice", async () => {
      // withdraw
      let nonceForAlice = await balanceManager.nonce(alice.address);
      let signatureForAlice = await getSignature(maintainer, alice.address, WITHDRAW_AMOUNT, nonceForAlice);
      await balanceManager
        .connect(maintainer)
        .withdraw(alice.address, WITHDRAW_AMOUNT, nonceForAlice, signatureForAlice);

      // witdraw again with the same signature
      await expect(
        balanceManager
          .connect(maintainer)
          .withdraw(alice.address, WITHDRAW_AMOUNT, nonceForAlice + 1, signatureForAlice),
      ).to.be.revertedWith("used signature");
    });

    it("revert if the amount is wrong", async () => {
      // withdraw
      let nonceForAlice = await balanceManager.nonce(alice.address);
      let signatureForAlice = await getSignature(maintainer, alice.address, WITHDRAW_AMOUNT, nonceForAlice);

      await expect(
        balanceManager.connect(maintainer).withdraw(bob.address, WITHDRAW_AMOUNT, nonceForAlice, signatureForAlice),
      ).to.be.revertedWith("wrong signer");
    });

    it("revert if the amount is wrong", async () => {
      // withdraw
      let nonceForAlice = await balanceManager.nonce(alice.address);
      let signatureForAlice = await getSignature(maintainer, alice.address, WITHDRAW_AMOUNT, nonceForAlice);

      await expect(
        balanceManager
          .connect(maintainer)
          .withdraw(alice.address, WITHDRAW_AMOUNT + 1, nonceForAlice, signatureForAlice),
      ).to.be.revertedWith("wrong signer");
    });
  });
});
