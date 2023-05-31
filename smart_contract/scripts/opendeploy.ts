import { ethers } from "hardhat";

const main = async () => {
    const Transactions = await ethers.getContractFactory("openzeppelinDemo");
    const transactions = await Transactions.deploy();
    await transactions.deployed();
    console.log("openzeppelinDemo deployed to:", transactions.address);
}

const runMain = async () => {
    try {
        await main();
        process.exit(0);
    }catch (e) {
        console.error(e);
        process.exit(1);
    }
}

runMain();
