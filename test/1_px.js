const { expect } = require("chai");
const Perlin = artifacts.require("Token");
const PerlinX = artifacts.require("PerlinXRewards");
const LP1 = artifacts.require("Token");
const LP2 = artifacts.require("Token");
const BigNumber = require('bignumber.js')
const truffleAssert = require('truffle-assertions')

function BN2Str(BN) { return ((new BigNumber(BN)).toFixed()) }
function getBN(BN) { return (new BigNumber(BN)) }

var acc0; var acc1; var acc2;
var perlin; var perlinX; var lp1; var lp2;
var accounts;

const REWARD = '172200000000000000000000'
const BALANCE = '100000000000000000000'
const BAL = '10000000000000000000'

before(async function() {
  accounts = await ethers.getSigners();
  acc0 = await accounts[0].getAddress()
  acc1 = await accounts[1].getAddress()
  acc2 = await accounts[2].getAddress()
  perlin = await Perlin.new();
  perlinX = await PerlinX.new(perlin.address);
  lp1 = await LP1.new();
  lp2 = await LP2.new();
  await perlin.transfer(lp1.address, BAL)
  await perlin.transfer(lp2.address, BAL)
  await lp1.transfer(acc1, BALANCE)
  await lp2.transfer(acc2, BALANCE)
})

describe("PerlinXRewards", function() {
  it("Should deploy", async function() {
    expect(await perlinX.PERL()).to.equal(perlin.address);
    expect(BN2Str(await perlinX.WEEKS())).to.equal('11');
  });
  it("Update Constants", async function() {
    await perlinX.updateConstants('12');
    expect(BN2Str(await perlinX.WEEKS())).to.equal('12');
  });
  it("addReward", async function() {
    await perlin.approve(perlinX.address, REWARD)
    expect(BN2Str(await perlin.allowance(acc0, perlinX.address))).to.equal(REWARD)
    await perlinX.addReward(REWARD);
    expect(BN2Str(await perlinX.TOTALREWARD())).to.equal(REWARD);
    expect(BN2Str(await perlin.balanceOf(perlinX.address))).to.equal(REWARD);
  });
  it("removeReward", async function() {
    await perlinX.removeReward('100000000000000000000');
    expect(BN2Str(await perlinX.TOTALREWARD())).to.equal('172100000000000000000000');
  });
  it("listPool", async function() {
    await perlinX.listPool(lp1.address);
    expect(await perlinX.poolIsListed(lp1.address)).to.equal(true);
    expect(BN2Str(await perlinX.poolCount())).to.equal('1');
    expect(await perlinX.arrayPerlinPools(0)).to.equal(lp1.address);
  });
  it("delistPool", async function() {
    await perlinX.delistPool(lp1.address);
    expect(await perlinX.poolIsListed(lp1.address)).to.equal(false);
    expect(BN2Str(await perlinX.poolCount())).to.equal('0');
    expect(await perlinX.arrayPerlinPools(0)).to.equal(lp1.address);
  });
  it("listPool again", async function() {
    await perlinX.listPool(lp1.address);
    expect(await perlinX.poolIsListed(lp1.address)).to.equal(true);
    expect(BN2Str(await perlinX.poolCount())).to.equal('1');
    expect(await perlinX.arrayPerlinPools(0)).to.equal(lp1.address);
    await perlinX.listPool(lp2.address);
    expect(await perlinX.poolIsListed(lp2.address)).to.equal(true);
    expect(BN2Str(await perlinX.poolCount())).to.equal('2');
    expect(await perlinX.arrayPerlinPools(1)).to.equal(lp2.address);
  });
  it("Users Locks LP1", async function() {
    await lp1.approve(perlinX.address, BALANCE, {from:acc1})
    await perlinX.lock(lp1.address, BALANCE, {from:acc1});
    expect(BN2Str(await perlinX.balancePool(lp1.address))).to.equal(BALANCE);
    expect(BN2Str(await perlinX.mapMemberPool_Balance(acc1, lp1.address))).to.equal(BALANCE);
  });
  it("Users Locks LP2", async function() {
    await lp2.approve(perlinX.address, BALANCE, {from:acc2})
    await perlinX.lock(lp2.address, BALANCE, {from:acc2});
    expect(BN2Str(await perlinX.balancePool(lp2.address))).to.equal(BALANCE);
    expect(BN2Str(await perlinX.mapMemberPool_Balance(acc2, lp2.address))).to.equal(BALANCE);
  });
  it("Admin Snapshots", async function() {
    await perlinX.snapshotPools('1');
    expect(BN2Str(await perlinX.mapEraPool_Balance('1', lp1.address))).to.equal(BAL);
    expect(BN2Str(await perlinX.mapEra_Total('1'))).to.equal('20000000000000000000');
    let share = '7170833333333333333333'
    expect(BN2Str(await perlinX.mapEraPool_Share('1', lp1.address))).to.equal(share);
  });
  it("Users claims", async function() {
    await perlinX.claim('1', lp1.address, {from:acc1});
    expect(BN2Str(await perlin.balanceOf(perlinX.address))).to.equal('164929166666666666666667');
    expect(BN2Str(await perlin.balanceOf(acc1))).to.equal('7170833333333333333333');
    await perlinX.claim('1', lp2.address, {from:acc2});
    expect(BN2Str(await perlin.balanceOf(perlinX.address))).to.equal('157758333333333333333334');
    expect(BN2Str(await perlin.balanceOf(acc2))).to.equal('7170833333333333333333');
  });
  it("Users unlocks", async function() {
    await perlinX.unlock(lp1.address, {from:acc1});
    expect(BN2Str(await lp1.balanceOf(perlinX.address))).to.equal('0');
    expect(BN2Str(await lp1.balanceOf(acc1))).to.equal(BALANCE);
    await perlinX.unlock(lp2.address, {from:acc2});
    expect(BN2Str(await lp2.balanceOf(perlinX.address))).to.equal('0');
    expect(BN2Str(await lp2.balanceOf(acc2))).to.equal(BALANCE);
  });
});
