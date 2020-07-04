// We require the Buidler Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `buidler run <script>` you'll find the Buidler
// Runtime Environment's members available in the global scope.
// const ethers = require('ethers')
const bre = require("@nomiclabs/buidler");
const Perlin = artifacts.require("Token");
const PerlinX = artifacts.require("PerlinXRewards");
const LP1 = artifacts.require("Token");
const LP2 = artifacts.require("Token");

async function main() {
  // Buidler always runs the compile task when running scripts through it. 
  // If this runs in a standalone fashion you may want to call compile manually 
  // to make sure everything is compiled
  // await bre.run('compile');

  // We get the contract to deploy
  // const Greeter = await ethers.getContractFactory("Greeter");
  const perlin = await Perlin.new();
  const perlinX = await PerlinX.new(perlin.address);
  const lp1 = await LP1.new();
  const lp2 = await LP2.new();

  // await greeter.deployed();

  console.log("perlin deployed to:", perlin.address);
  console.log("perlinX deployed to:", perlinX.address);
  console.log("lp1 deployed to:", lp1.address);
  console.log("lp2 deployed to:", lp2.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
