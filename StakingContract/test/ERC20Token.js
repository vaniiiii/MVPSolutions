const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { assert, expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("ERC20Token", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployERC20TokenFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, vani, alice, bob] = await ethers.getSigners();

    const provider = ethers.provider;

    const ERC20Token = await ethers.getContractFactory("ERC20Token");

    const token = await ERC20Token.deploy();

    return {
      token,
      owner,
      vani,
    };
  }

  describe("Deployment", function () {
    it("Should deploy and set the token", async function () {
      const { token, owner } = await loadFixture(deployERC20TokenFixture);
      assert(token.target !== ethers.ZeroAddress, "deployment failed");
      expect(await token.owner()).to.equal(owner.address);
      expect(await token.totalSupply()).to.equal(0);
    });
  });
  describe("Mint", function () {
    describe("ShouldPass", function () {
      it("Should mint", async function () {
        const { token, vani } = await loadFixture(deployERC20TokenFixture);
        const amount = ethers.parseEther("0.5");
        const totalSupplyBefore = await token.totalSupply();
        const balanaceBefore = await token.balanceOf(vani);
        await token.mint(vani, amount);

        expect(await token.totalSupply()).to.equal(totalSupplyBefore + amount);
        expect(await token.balanceOf(vani)).to.equal(balanaceBefore + amount);
      });
      it("Should emit proper event", async function () {
        const { token, vani } = await loadFixture(deployERC20TokenFixture);
        const amount = ethers.parseEther("0.5");
        await expect(token.mint(vani, amount))
          .to.emit(token, "Transfer")
          .withArgs(ethers.ZeroAddress, vani.address, amount);
      });
    });
    describe("ShouldFail", function () {
      it("Should fail if minter is not owner", async function () {
        const { token, vani } = await loadFixture(deployERC20TokenFixture);
        const amount = ethers.parseEther("0.5");
        await expect(
          token.connect(vani).mint(vani, amount)
        ).to.be.revertedWithCustomError(token, "NotAuthorized");
      });
    });
  });
  describe("Burn", function () {
    describe("ShouldPass", function () {
      it("Should burn", async function () {
        const { token, vani } = await loadFixture(deployERC20TokenFixture);
        const amount = ethers.parseEther("0.5");

        await token.mint(vani, amount);

        const balanaceBefore = await token.balanceOf(vani);
        const totalSupplyBefore = await token.balanceOf(vani);

        await token.connect(vani).approve(token.target, amount);
        await token.burn(vani, amount);

        expect(await token.totalSupply()).to.equal(totalSupplyBefore - amount);
        expect(await token.balanceOf(vani)).to.equal(balanaceBefore - amount);
      });
      it("Should emit proper event", async function () {
        const { token, vani } = await loadFixture(deployERC20TokenFixture);
        const amount = ethers.parseEther("0.5");

        await token.mint(vani, amount);
        await token.connect(vani).approve(token.target, amount);

        await expect(token.burn(vani, amount))
          .to.emit(token, "Transfer")
          .withArgs(vani.address, ethers.ZeroAddress, amount);
      });
    });
    describe("ShouldFail", function () {
      it("Should fail if burner is not deployer", async function () {
        const { token, vani } = await loadFixture(deployERC20TokenFixture);
        const amount = ethers.parseEther("0.5");
        await token.mint(vani, amount);
        await token.connect(vani).approve(token.target, amount);
        await expect(
          token.connect(vani).burn(vani, amount)
        ).to.be.revertedWithCustomError(token, "NotAuthorized");
      });
    });
  });
});
