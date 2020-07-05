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

const REWARD = '172200000000000000000000' // 1200
const LP_BAL = '100000000000000000000' // 100
const LP_BAL2 = '200000000000000000000' // 200
const PERL_BAL = '10000000000000000000' // 10
const PERL_BAL2 = '20000000000000000000' // 20
const PERL_BAL4 = '40000000000000000000' // 40


before(async function() {
  accounts = await ethers.getSigners();
  acc0 = await accounts[0].getAddress()
  acc1 = await accounts[1].getAddress()
  acc2 = await accounts[2].getAddress()
  perlin = await Perlin.new();
  perlinX = await PerlinX.new(perlin.address);
  lp1 = await LP1.new();
  lp2 = await LP2.new();
  await perlin.transfer(lp1.address, PERL_BAL)
  await perlin.transfer(lp2.address, PERL_BAL2)
  await lp1.transfer(acc1, LP_BAL)
  await lp1.transfer(acc2, LP_BAL)
  await lp2.transfer(acc2, LP_BAL)
})

describe("PerlinXRewards", function() {
  it("Should deploy", async function() {
    expect(await perlinX.PERL()).to.equal(perlin.address);
    expect(BN2Str(await perlinX.WEEKS())).to.equal('10');
  });
  it("Update Constants", async function() {
    await perlinX.updateConstants('12');
    expect(BN2Str(await perlinX.WEEKS())).to.equal('12');
  });
  it("addReward", async function() {
    await perlin.approve(perlinX.address, REWARD)
    expect(BN2Str(await perlin.allowance(acc0, perlinX.address))).to.equal(REWARD)
    await perlinX.addReward(REWARD);
    // expect(BN2Str(await perlinX.TOTALREWARD())).to.equal(REWARD);
    expect(BN2Str(await perlin.balanceOf(perlinX.address))).to.equal(REWARD);
  });
  it("removeReward", async function() {
    await perlinX.removeReward('100000000000000000000');
    // expect(BN2Str(await perlinX.TOTALREWARD())).to.equal('172100000000000000000000');
    expect(BN2Str(await perlin.balanceOf(perlinX.address))).to.equal('172100000000000000000000');
  });
  it("addReward again", async function() {
    await perlin.approve(perlinX.address, REWARD)
    await perlinX.addReward('100000000000000000000');
    expect(BN2Str(await perlin.balanceOf(perlinX.address))).to.equal(REWARD);
  });
  it("listPool", async function() {
    await perlinX.listPool(lp1.address, '100');
    expect(await perlinX.poolIsListed(lp1.address)).to.equal(true);
    expect(BN2Str(await perlinX.poolCount())).to.equal('1');
    expect(await perlinX.arrayPerlinPools(0)).to.equal(lp1.address);
    expect(BN2Str(await perlinX.poolFactor(lp1.address))).to.equal('100');
  });
  it("delistPool", async function() {
    await perlinX.delistPool(lp1.address);
    expect(await perlinX.poolIsListed(lp1.address)).to.equal(false);
    expect(BN2Str(await perlinX.poolCount())).to.equal('1');
    expect(await perlinX.arrayPerlinPools(0)).to.equal(lp1.address);
  });
  it("listPool again", async function() {
    await perlinX.listPool(lp1.address, '100');
    expect(await perlinX.poolIsListed(lp1.address)).to.equal(true);
    expect(BN2Str(await perlinX.poolCount())).to.equal('1');
    expect(await perlinX.arrayPerlinPools(0)).to.equal(lp1.address);
    expect(BN2Str(await perlinX.poolFactor(lp1.address))).to.equal('100');
    await perlinX.listPool(lp2.address, '200');
    expect(await perlinX.poolIsListed(lp2.address)).to.equal(true);
    expect(BN2Str(await perlinX.poolCount())).to.equal('2');
    expect(await perlinX.arrayPerlinPools(1)).to.equal(lp2.address);
    expect(BN2Str(await perlinX.poolFactor(lp2.address))).to.equal('200');
  });
  // 1 User, 1 Pool
  it("Users Locks LP1", async function() {
    await lp1.approve(perlinX.address, LP_BAL, {from:acc1})
    await perlinX.lock(lp1.address, LP_BAL, {from:acc1});
    expect(BN2Str(await lp1.balanceOf(perlinX.address))).to.equal(LP_BAL);
    expect(BN2Str(await perlinX.mapMemberPool_Balance(acc1, lp1.address))).to.equal(LP_BAL);
  });
  it("Admin Snapshots", async function() {
    await perlinX.snapshotPools();
    expect(BN2Str(await perlinX.mapWeekPool_Weight('1', lp1.address))).to.equal(PERL_BAL);
    expect(BN2Str(await perlinX.mapWeek_Total('1'))).to.equal('10000000000000000000');
    expect(BN2Str(await perlinX.mapWeekPool_Share('1', lp1.address))).to.equal('14350000000000000000000');
    expect(BN2Str(await perlinX.mapWeekPool_Share('1', lp2.address))).to.equal('0');
  });
  it("Users checks", async function() {
    let mapWeekPool_Share = BN2Str(await perlinX.mapWeekPool_Share('1', lp1.address))
    let mapMemberWeekPool_Claim = BN2Str(await perlinX.mapMemberWeekPool_Claim(acc1, '1', lp1.address))
    let mapWeekPool_Balance = BN2Str(await perlinX.mapWeekPool_Claims('1', lp1.address))
    // console.log('mapWeekPool_Share', mapWeekPool_Share)
    // console.log('mapMemberWeekPool_Claim', mapMemberWeekPool_Claim)
    // console.log('mapWeekPool_Balance', mapWeekPool_Balance)
    expect(BN2Str(await perlinX.getShare(mapMemberWeekPool_Claim, mapWeekPool_Balance, mapWeekPool_Share))).to.equal('14350000000000000000000');
    expect(BN2Str(await perlinX.checkClaimInPool(acc1, '1', lp1.address))).to.equal('14350000000000000000000');
    expect(BN2Str(await perlinX.checkClaimInPool(acc2, '1', lp2.address))).to.equal('0');
    expect(BN2Str(await perlinX.checkClaim(acc1, '1'))).to.equal('14350000000000000000000');
    expect(BN2Str(await perlinX.checkClaim(acc2, '1'))).to.equal('0');
  });
  it("Users claims", async function() {
    await perlinX.claim('1', {from:acc1});
    expect(BN2Str(await perlin.balanceOf(perlinX.address))).to.equal('157850000000000000000000');
    expect(BN2Str(await perlin.balanceOf(acc1))).to.equal('14350000000000000000000');
    await perlinX.claim('1', {from:acc2});
    expect(BN2Str(await perlin.balanceOf(perlinX.address))).to.equal('157850000000000000000000');
    expect(BN2Str(await perlin.balanceOf(acc2))).to.equal('0');
  });
  // 2 Users, 1 Pool Each
  it("User 2 Locks LP2", async function() {
    await lp2.approve(perlinX.address, LP_BAL, {from:acc2})
    await perlinX.lock(lp2.address, LP_BAL, {from:acc2});
    expect(BN2Str(await lp2.balanceOf(perlinX.address))).to.equal(LP_BAL);
    expect(BN2Str(await perlinX.mapMemberPool_Balance(acc2, lp2.address))).to.equal(LP_BAL);
  });
  it("Admin Snapshots", async function() {
    await perlinX.snapshotPools();
    expect(BN2Str(await perlinX.mapWeekPool_Weight('2', lp1.address))).to.equal(PERL_BAL);
    expect(BN2Str(await perlinX.mapWeek_Total('2'))).to.equal('50000000000000000000');
    expect(BN2Str(await perlinX.mapWeekPool_Share('2', lp1.address))).to.equal('2870000000000000000000');
    expect(BN2Str(await perlinX.mapWeekPool_Share('2', lp2.address))).to.equal('11480000000000000000000');
  });
  it("Users checks", async function() {
    let mapWeekPool_Share = BN2Str(await perlinX.mapWeekPool_Share('2', lp1.address))
    let mapMemberWeekPool_Claim = BN2Str(await perlinX.mapMemberWeekPool_Claim(acc1, '2', lp1.address))
    let mapWeekPool_Balance = BN2Str(await perlinX.mapWeekPool_Claims('2', lp1.address))
    expect(BN2Str(await perlinX.getShare(mapMemberWeekPool_Claim, mapWeekPool_Balance, mapWeekPool_Share))).to.equal('2870000000000000000000');
    expect(BN2Str(await perlinX.checkClaimInPool(acc1, '2', lp1.address))).to.equal('2870000000000000000000');
    expect(BN2Str(await perlinX.checkClaimInPool(acc2, '2', lp2.address))).to.equal('11480000000000000000000');
    expect(BN2Str(await perlinX.checkClaim(acc1, '2'))).to.equal('2870000000000000000000');
    expect(BN2Str(await perlinX.checkClaim(acc2, '2'))).to.equal('11480000000000000000000');
  });
  it("Users claims", async function() {
    await perlinX.claim('2', {from:acc1});
    expect(BN2Str(await perlin.balanceOf(perlinX.address))).to.equal('154980000000000000000000');
    expect(BN2Str(await perlin.balanceOf(acc1))).to.equal('17220000000000000000000');
    await perlinX.claim('2', {from:acc2});
    expect(BN2Str(await perlin.balanceOf(perlinX.address))).to.equal('143500000000000000000000');
    expect(BN2Str(await perlin.balanceOf(acc2))).to.equal('11480000000000000000000');
    expect(BN2Str(await perlinX.mapWeekPool_Claims('3', lp1.address))).to.equal(LP_BAL);
    expect(BN2Str(await perlinX.mapWeekPool_Claims('3', lp2.address))).to.equal(LP_BAL);
  });
  // 2 Users, 1 with 2 pools  
  it("User 2 Locks LP1", async function() {
    await lp1.approve(perlinX.address, LP_BAL, {from:acc2})
    await perlinX.lock(lp1.address, LP_BAL, {from:acc2});
    expect(BN2Str(await lp1.balanceOf(perlinX.address))).to.equal(LP_BAL2);
    expect(BN2Str(await perlinX.mapMemberPool_Balance(acc2, lp1.address))).to.equal(LP_BAL);
    expect(BN2Str(await perlinX.mapWeekPool_Claims('3', lp1.address))).to.equal(LP_BAL2);
    expect(BN2Str(await perlinX.mapMemberWeekPool_Claim(acc1, '3', lp1.address))).to.equal(LP_BAL);
    expect(BN2Str(await perlinX.mapMemberWeekPool_Claim(acc2, '3', lp1.address))).to.equal(LP_BAL);
    expect(BN2Str(await perlinX.mapMemberWeekPool_Claim(acc2, '3', lp2.address))).to.equal(LP_BAL);
  });
  it("Admin Snapshots", async function() {
    await perlinX.snapshotPools();
    expect(BN2Str(await perlinX.mapWeekPool_Weight('3', lp1.address))).to.equal(PERL_BAL);
    expect(BN2Str(await perlinX.mapWeekPool_Weight('3', lp2.address))).to.equal(PERL_BAL4);
    expect(BN2Str(await perlinX.mapWeek_Total('3'))).to.equal('50000000000000000000');
    expect(BN2Str(await perlinX.mapWeekPool_Share('3', lp1.address))).to.equal('2870000000000000000000');
    expect(BN2Str(await perlinX.mapWeekPool_Share('3', lp2.address))).to.equal('11480000000000000000000');
  });
  it("Users checks", async function() {
    let mapWeekPool_Share = BN2Str(await perlinX.mapWeekPool_Share('3', lp1.address))
    let mapMemberWeekPool_Claim = BN2Str(await perlinX.mapMemberWeekPool_Claim(acc1, '3', lp1.address))
    let mapWeekPool_Balance = BN2Str(await perlinX.mapWeekPool_Claims('3', lp1.address))
    expect(BN2Str(await perlinX.getShare(mapMemberWeekPool_Claim, mapWeekPool_Balance, mapWeekPool_Share))).to.equal('1435000000000000000000');
    expect(BN2Str(await perlinX.checkClaimInPool(acc1, '3', lp1.address))).to.equal('1435000000000000000000');
    expect(BN2Str(await perlinX.checkClaimInPool(acc2, '3', lp1.address))).to.equal('1435000000000000000000');
    expect(BN2Str(await perlinX.checkClaimInPool(acc2, '3', lp2.address))).to.equal('11480000000000000000000');
    expect(BN2Str(await perlinX.checkClaim(acc1, '3'))).to.equal('1435000000000000000000');
    expect(BN2Str(await perlinX.checkClaim(acc2, '3'))).to.equal('12915000000000000000000');
  });
  it("Users claims", async function() {
    await perlinX.claim('3', {from:acc1});
    expect(BN2Str(await perlin.balanceOf(perlinX.address))).to.equal('142065000000000000000000');
    expect(BN2Str(await perlin.balanceOf(acc1))).to.equal('18655000000000000000000');
    await perlinX.claim('3', {from:acc2});
    expect(BN2Str(await perlin.balanceOf(perlinX.address))).to.equal('129150000000000000000000');
    expect(BN2Str(await perlin.balanceOf(acc2))).to.equal('24395000000000000000000');
  });

  it("Users unlocks", async function() {
    await perlinX.unlock(lp1.address, {from:acc1});
    expect(BN2Str(await lp1.balanceOf(perlinX.address))).to.equal('100000000000000000000');
    expect(BN2Str(await lp1.balanceOf(acc1))).to.equal(LP_BAL);
    await perlinX.unlock(lp1.address, {from:acc2});
    expect(BN2Str(await lp1.balanceOf(perlinX.address))).to.equal('0');
    expect(BN2Str(await lp1.balanceOf(acc2))).to.equal(LP_BAL);
    await perlinX.unlock(lp2.address, {from:acc2});
    expect(BN2Str(await lp2.balanceOf(perlinX.address))).to.equal('0');
    expect(BN2Str(await lp2.balanceOf(acc2))).to.equal(LP_BAL);
  });
});
