const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const helpers = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { assert, expect } = require("chai");
const { ethers, network } = require("hardhat");
require("dotenv").config();

describe("StakingContractBytes", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployStakingContractFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, vani, alice, bob] = await ethers.getSigners();
    // const vani = await ethers.getImpersonatedSigner("0xF913dA8d4725988cDF1Ae6BfaF3c3b7836AE8faa");
    const provider = ethers.provider;
    const uint104Max = "20282409603651670423947251286015";
    const uint48Max = "281474976710655";

    const StakingContract = await ethers.getContractFactory(
      "StakingContractBytes"
    );
    const ERC20Token = await ethers.getContractFactory("ERC20Token");

    const MockV3Aggregator = await ethers.getContractFactory(
      "MockV3Aggregator"
    );
    const CanNotRecieveETH = await ethers.getContractFactory(
      "CanNotRecieveETH"
    );

    let stakingcontract;
    let datafeed;

    if (provider._networkName === "localhost") {
      stakingcontract = await StakingContract.deploy(
        process.env.ETH_USD_ORACLE
      );
      datafeed = await ethers.getContractAt(
        "MockV3Aggregator",
        await stakingcontract.dataFeed()
      );
    } else {
      datafeed = await MockV3Aggregator.deploy(8, 165000000000);
      stakingcontract = await StakingContract.deploy(datafeed.target);
    }

    const token = await ethers.getContractAt(
      "ERC20Token",
      await stakingcontract.token()
    );

    const cannotrecieveeth = await CanNotRecieveETH.deploy(
      stakingcontract.target,
      token.target
    );
    const minStakingPeriod = await stakingcontract.MINIMUM_STAKING_PERIOD();

    return {
      stakingcontract,
      token,
      datafeed,
      cannotrecieveeth,
      owner,
      vani,
      alice,
      bob,
      minStakingPeriod,
      uint104Max,
      uint48Max,
      provider,
    };
  }

  describe("Deployment", function () {
    it("Should deploy and set the token", async function () {
      const { stakingcontract, token, datafeed } = await loadFixture(
        deployStakingContractFixture
      );
      assert(
        stakingcontract.target !== ethers.ZeroAddress,
        "deployment failed"
      );
      expect(await token.owner()).to.equal(stakingcontract.target);
      expect(await token.totalSupply()).to.equal(0);
      expect(await datafeed.decimals()).to.equal(8);
    });
  });

  describe("Stake", function () {
    describe("ShouldPass", function () {
      it("Should stake", async function () {
        const { stakingcontract, token, vani, minStakingPeriod } =
          await loadFixture(deployStakingContractFixture);

        const stakingValue = ethers.parseEther("0.5");
        const totalStakedBefore = await stakingcontract.totalStaked();
        const amount = (await stakingcontract.priceFeed()) * stakingValue;

        await stakingcontract
          .connect(vani)
          .stake(minStakingPeriod, { value: stakingValue });
        const startTime = BigInt(await time.latest());
        const [data, ETHAmount, ERC20Amount, endTime] =
          await stakingcontract.getStakePosition(vani.address, 0);
        expect(await stakingcontract.totalStaked()).to.equal(
          totalStakedBefore + stakingValue
        );
        expect(await token.totalSupply()).to.equal(amount);

        expect(await stakingcontract.ids(vani)).to.equal(1);
        expect(endTime).to.equal(startTime + minStakingPeriod);
        expect(ETHAmount).to.equal(stakingValue);
        expect(ERC20Amount).to.equal(amount);
      });

      it("Should create multiple positions", async function () {
        const { stakingcontract, token, vani, minStakingPeriod } =
          await loadFixture(deployStakingContractFixture);

        const stakingValueOne = ethers.parseEther("0.5");
        const stakingValueTwo = ethers.parseEther("1.4");
        const totalStakedBefore = await stakingcontract.totalStaked();
        const amountOne = (await stakingcontract.priceFeed()) * stakingValueOne;
        const amountTwo = (await stakingcontract.priceFeed()) * stakingValueTwo;

        await stakingcontract
          .connect(vani)
          .stake(minStakingPeriod, { value: stakingValueOne });
        const startTimeFirstPosition = BigInt(await time.latest());

        await stakingcontract
          .connect(vani)
          .stake(minStakingPeriod + BigInt(3600), { value: stakingValueTwo });

        const startTimeSecondPosition = BigInt(await time.latest());

        const [, , , endTimeOne] = await stakingcontract.getStakePosition(
          vani.address,
          0
        );
        const [, , , endTimeTwo] = await stakingcontract.getStakePosition(
          vani.address,
          1
        );

        expect(await stakingcontract.totalStaked()).to.equal(
          totalStakedBefore + (stakingValueOne + stakingValueTwo)
        );
        expect(await token.totalSupply()).to.equal(amountOne + amountTwo);

        expect(await stakingcontract.ids(vani)).to.equal(2);
        expect(endTimeOne).to.equal(startTimeFirstPosition + minStakingPeriod);
        expect(endTimeTwo).to.equal(
          startTimeSecondPosition + minStakingPeriod + BigInt(3600)
        );
      });
      it("Should emit proper event", async function () {
        const { stakingcontract, vani, minStakingPeriod } = await loadFixture(
          deployStakingContractFixture
        );
        const stakingValue = ethers.parseEther("0.1");
        await expect(
          stakingcontract
            .connect(vani)
            .stake(minStakingPeriod, { value: stakingValue })
        )
          .to.emit(stakingcontract, "Staked")
          .withArgs(vani.address, stakingValue, 0, minStakingPeriod);
      });
    });

    describe("ShouldFail", function () {
      it("Should fail if staking period is shorter than minimum", async function () {
        const { stakingcontract, minStakingPeriod } = await loadFixture(
          deployStakingContractFixture
        );
        const stakingValue = ethers.parseEther("0.5");
        await expect(
          stakingcontract.stake(minStakingPeriod - BigInt(3600), {
            value: stakingValue,
          })
        ).to.be.revertedWithCustomError(
          stakingcontract,
          "MinimumStakingPeriodTooShort"
        );
      });
      it("Should fail if msg.value is zero", async function () {
        const { stakingcontract, minStakingPeriod } = await loadFixture(
          deployStakingContractFixture
        );
        await expect(
          stakingcontract.stake(minStakingPeriod, {
            value: 0,
          })
        ).to.be.revertedWithCustomError(stakingcontract, "ZeroStakingAmount");
      });
      it("Should fail if staking amount is bigger than uint104 maximum value", async function () {});
      it("Should fail if token amount is bigger than uint104 maximum value", async function () {
        const { stakingcontract, minStakingPeriod, datafeed, provider } =
          await loadFixture(deployStakingContractFixture);
        if (provider._networkName === "localhost") {
          return;
        } else {
          const stakingValue = 1; // wei;

          await datafeed.updateAnswer(
            "2028240960365167042394725128601600000000"
          );

          await expect(
            stakingcontract.stake(minStakingPeriod, {
              value: stakingValue,
            })
          ).to.be.revertedWithCustomError(stakingcontract, "CastOverflow");
        }
      });
      it("Should fail if staking period is bigger than uint48", async function () {
        const { stakingcontract, minStakingPeriod, uint48Max } =
          await loadFixture(deployStakingContractFixture);
        const stakingValue = ethers.parseEther("0.5");
        const timeStamp = await time.latest();
        await expect(
          stakingcontract.stake(uint48Max - timeStamp, {
            value: stakingValue,
          })
        ).to.be.revertedWithCustomError(stakingcontract, "CastOverflow");
      });
      it("Should fail if data is stale", async function () {
        const { stakingcontract, minStakingPeriod, datafeed, provider } =
          await loadFixture(deployStakingContractFixture);

        if (provider._networkName === "localhost") {
          return;
        } else {
          const stakingValue = ethers.parseEther("0.5");

          await datafeed.updateRoundData(
            0,
            "165000000000",
            (await time.latest()) - 3600,
            await time.latest()
          );

          await expect(
            stakingcontract.stake(minStakingPeriod, {
              value: stakingValue,
            })
          ).to.be.revertedWithCustomError(stakingcontract, "StaleData");
        }
      });
      it("Should fail if price is zero", async function () {
        const { stakingcontract, minStakingPeriod, datafeed, provider } =
          await loadFixture(deployStakingContractFixture);
        if (provider._networkName === "localhost") {
          return;
        } else {
          const stakingValue = ethers.parseEther("0.5");

          await datafeed.updateAnswer(0);

          await expect(
            stakingcontract.stake(minStakingPeriod, {
              value: stakingValue,
            })
          ).to.be.revertedWithCustomError(stakingcontract, "ZeroPrice");
        }
      });
    });
  });
  describe("Unstake", function () {
    describe("ShouldPass", function () {
      it("Should unstake", async function () {
        const { stakingcontract, token, vani, minStakingPeriod } =
          await loadFixture(deployStakingContractFixture);

        const stakingValue = ethers.parseEther("0.5");
        const amount = (await stakingcontract.priceFeed()) * stakingValue;

        await stakingcontract
          .connect(vani)
          .stake(minStakingPeriod, { value: stakingValue });

        const endTime = BigInt(await time.latest()) + minStakingPeriod;
        await time.increaseTo(endTime);

        const totalStakedBefore = await stakingcontract.totalStaked();
        const tokenSupplyBefore = await token.totalSupply();
        const [, , ERC20Amount] = await stakingcontract.getStakePosition(
          vani.address,
          0
        );

        await token.connect(vani).approve(stakingcontract.target, amount);
        await stakingcontract.connect(vani).unstake(0);

        const [, , , endTime_] = await stakingcontract.getStakePosition(
          vani.address,
          0
        );

        expect(await stakingcontract.totalStaked()).to.equal(
          totalStakedBefore - stakingValue
        );
        expect(await token.totalSupply()).to.equal(
          tokenSupplyBefore - ERC20Amount
        );
        expect(endTime_).to.equal(0);
      });
      it("Should unstake multiple positions", async function () {
        const { stakingcontract, token, vani, minStakingPeriod } =
          await loadFixture(deployStakingContractFixture);

        const stakingValueOne = ethers.parseEther("0.5");
        const stakingValueTwo = ethers.parseEther("1.4");
        const amountOne = (await stakingcontract.priceFeed()) * stakingValueOne;
        const amountTwo = (await stakingcontract.priceFeed()) * stakingValueTwo;

        await stakingcontract
          .connect(vani)
          .stake(minStakingPeriod, { value: stakingValueOne });
        const endTimeFirstPosition =
          BigInt(await time.latest()) + minStakingPeriod;

        await stakingcontract
          .connect(vani)
          .stake(minStakingPeriod + BigInt(3600), { value: stakingValueTwo });
        const endTimeSecondPosition =
          BigInt(await time.latest()) + minStakingPeriod + BigInt(3600);

        const totalStakedBefore = await stakingcontract.totalStaked();
        const tokenSupplyBefore = await token.totalSupply();
        const [, , ERC20AmountOne] = await stakingcontract.getStakePosition(
          vani.address,
          0
        );

        const [, , ERC20AmountTwo] = await stakingcontract.getStakePosition(
          vani.address,
          1
        );

        await time.increaseTo(endTimeFirstPosition);
        await token
          .connect(vani)
          .approve(stakingcontract.target, amountOne + amountTwo);
        await stakingcontract.connect(vani).unstake(0);

        await time.increaseTo(endTimeSecondPosition);
        await stakingcontract.connect(vani).unstake(1);

        const [, , , endTimeOne] = await stakingcontract.getStakePosition(
          vani.address,
          0
        );

        const [, , , endTimeTwo] = await stakingcontract.getStakePosition(
          vani.address,
          1
        );

        expect(await stakingcontract.totalStaked()).to.equal(
          totalStakedBefore - stakingValueOne - stakingValueTwo
        );
        expect(await token.totalSupply()).to.equal(
          tokenSupplyBefore - ERC20AmountOne - ERC20AmountTwo
        );
        expect(endTimeOne).to.equal(0);
        expect(endTimeTwo).to.equal(0);
      });
      it("Should emit proper event", async function () {
        const { stakingcontract, token, vani, minStakingPeriod } =
          await loadFixture(deployStakingContractFixture);
        const stakingValue = ethers.parseEther("0.1");
        const amount = (await stakingcontract.priceFeed()) * stakingValue;

        await stakingcontract
          .connect(vani)
          .stake(minStakingPeriod, { value: stakingValue });

        const endTime = BigInt(await time.latest()) + minStakingPeriod;
        await time.increaseTo(endTime);

        await token.connect(vani).approve(stakingcontract.target, amount);

        expect(await stakingcontract.connect(vani).unstake(0))
          .to.emit(stakingcontract, "UnStaked")
          .withArgs(vani.address, amount, 0);
      });
    });
    describe("ShouldFail", function () {
      it("Should fail if staking period did not pass", async function () {
        const { stakingcontract, token, vani, minStakingPeriod } =
          await loadFixture(deployStakingContractFixture);

        const stakingValue = ethers.parseEther("0.5");
        const amount = (await stakingcontract.priceFeed()) * stakingValue;
        await stakingcontract
          .connect(vani)
          .stake(minStakingPeriod, { value: stakingValue });
        const endTime = BigInt(await time.latest()) + minStakingPeriod;
        await token.connect(vani).approve(stakingcontract.target, amount);
        await time.increaseTo(endTime - BigInt(2));
        await expect(
          stakingcontract.connect(vani).unstake(0)
        ).to.be.revertedWithCustomError(
          stakingcontract,
          "StakingPeriodNotPassed"
        );
      });
      it("Should fail if staking position is closed", async function () {
        const { stakingcontract, token, vani, minStakingPeriod } =
          await loadFixture(deployStakingContractFixture);

        const stakingValue = ethers.parseEther("0.5");
        const amount = (await stakingcontract.priceFeed()) * stakingValue;
        await stakingcontract
          .connect(vani)
          .stake(minStakingPeriod, { value: stakingValue });

        const endTime = BigInt(await time.latest()) + minStakingPeriod;
        await time.increaseTo(endTime);

        await token.connect(vani).approve(stakingcontract.target, amount);
        await stakingcontract.connect(vani).unstake(0);

        await expect(
          stakingcontract.connect(vani).unstake(0)
        ).to.be.revertedWithCustomError(
          stakingcontract,
          "StakePositionNotActive"
        );
      });
      it("Should fail if caller can not recieve eth(?)", async function () {
        const {
          stakingcontract,
          token,
          cannotrecieveeth,
          vani,
          minStakingPeriod,
        } = await loadFixture(deployStakingContractFixture);
        await vani.sendTransaction({
          to: cannotrecieveeth.target,
          value: ethers.parseEther("1"),
        });
        await cannotrecieveeth.connect(vani).stake();
        const endTime = BigInt(await time.latest()) + minStakingPeriod;
        await time.increaseTo(endTime);
        await expect(
          cannotrecieveeth.connect(vani).unstake()
        ).to.be.revertedWithCustomError(stakingcontract, "EtherTransferFailed");
      });
      it("Should fail if caller does not have enough ERC20 to return", async function () {});
    });
  });
});
