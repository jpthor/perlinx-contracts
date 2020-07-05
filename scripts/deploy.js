// We require the Buidler Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `buidler run <script>` you'll find the Buidler
// Runtime Environment's members available in the global scope.
// const ethers = require('ethers')
const bre = require("@nomiclabs/buidler");
const Perlin = artifacts.require("Perlin");
const PerlinX = artifacts.require("PerlinXRewards");
const LP1 = artifacts.require("Exchange1");
const LP2 = artifacts.require("Exchange2");

async function main() {
  // Buidler always runs the compile task when running scripts through it. 
  // If this runs in a standalone fashion you may want to call compile manually 
  // to make sure everything is compiled
  // await bre.run('compile');

  const LP_BAL = '100000000000000000000' // 100
  const PERL_BAL = '10000000000000000000' // 10

  // We get the contract to deploy
  // const Greeter = await ethers.getContractFactory("Greeter");
  const perlin = await Perlin.new();
  const perlinX = await PerlinX.new(perlin.address);
  const lp1 = await LP1.new();
  const lp2 = await LP2.new();

  // await greeter.deployed();

  console.log("perlinX deployed to:", perlinX.address);
  console.log("perlin deployed to:", perlin.address);
  console.log("lp1 deployed to:", lp1.address);
  console.log("lp2 deployed to:", lp2.address);

  // send PERL to exchanges to simulate staking
  // send LP tokens to acc1, acc2

  // accounts = await ethers.getSigners();
  // acc0 = await accounts[0].getAddress()
  // acc1 = await accounts[1].getAddress()
  // acc2 = await accounts[2].getAddress()

  // await perlin.transfer(lp1.address, PERL_BAL)
  // await perlin.transfer(lp2.address, PERL_BAL)
  // await lp1.transfer(acc1, LP_BAL)
  // await lp2.transfer(acc2, LP_BAL)

  // console.log(await lp1.balanceOf(acc0))
  // console.log(await lp1.balanceOf(acc1))
  // console.log(await lp2.balanceOf(acc2))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
