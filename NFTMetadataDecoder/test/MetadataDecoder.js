const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("MetadataDecoder", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployMetadataDecoderFixture() {
    // Contracts are deployed using the first signer/account by default

    const NFTMetadataDecoder = await ethers.getContractFactory("NFTMetadataDecoder");
    const metadatadecoder = await NFTMetadataDecoder.deploy(
      "0x0000000000000001018000ffd8da6bf26964af9d7eed9e03e53415d37aa96045"
    );
    const metadata =
      "0x0000000000000001018000ffd8da6bf26964af9d7eed9e03e53415d37aa96045";
    return { metadatadecoder, metadata };
  }

  describe("Deployment", function () {
    it("Should deploy and set the metadata", async function () {
      const { metadatadecoder } = await loadFixture(
        deployMetadataDecoderFixture
      );

      expect(await metadatadecoder.metadata()).to.equal(
        "0x0000000000000001018000ffd8da6bf26964af9d7eed9e03e53415d37aa96045"
      );
    });
  });

  describe("ExtractColor", function () {
    it("Should extract metadata stored as state variable", async function () {
      const { metadatadecoder } = await loadFixture(
        deployMetadataDecoderFixture
      );
      await expect(await metadatadecoder.getColorFromMetadata()).to.be.equal(8388863);
    });
  });
});
