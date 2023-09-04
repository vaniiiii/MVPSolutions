import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { ethers } from 'hardhat';
import { expect } from 'chai';

const TARGET_GAS_PRICE = 30000;

const logGasUsage = (currentGasUsage: number) => {
	const diff = TARGET_GAS_PRICE - currentGasUsage;
	console.log(`           Current gas use:   ${currentGasUsage}`);
	console.log(`           The gas target is: ${TARGET_GAS_PRICE}`);
	if (diff < 0) {
		console.log(
			`           You are \x1b[31m${diff * -1}\x1b[0m above the target`
		);
	}
};

describe('Gas Golfing Challenge - Looper', function () {
	async function deployLooper() {
		const Looper = await ethers.getContractFactory('Looper');
		const looper = await Looper.deploy();
		await looper.deployed();
		return looper;
	}

	it('The loop() function must be optimized', async function () {
		const looper = await loadFixture(deployLooper);
		
		const gasEstimate = await looper.estimateGas.loop();
		await looper.loop();

		logGasUsage(gasEstimate.toNumber());

		expect(gasEstimate.toNumber()).lte(TARGET_GAS_PRICE);
	});
});
