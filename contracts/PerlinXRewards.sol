//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@nomiclabs/buidler/console.sol";

// ERC20 Interface
interface ERC20 {
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

library SafeMath {

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }

}

contract PerlinXRewards {
  using SafeMath for uint;

  address public perlinAdmin;
  address[] public arrayPerlinPools;
  address public PERL;
  uint public WEEKS;
  uint public TOTALREWARD;
  uint public poolCount;
  uint public currentWeek;

  mapping(address => bool) public poolIsListed;       // Tracks current listing status
  mapping(address => bool) public poolHasMembers;       // Tracks current staking status
  mapping(address => bool) public poolWasListed;      // Tracks if pool was ever listed
  mapping(address => uint) public poolFactor;         // Allows a reward factor to be applied; 100 = 1.0
  mapping(uint => uint) public mapWeek_Total;         // Total PERL staked in each week
  mapping(uint => mapping(address => uint)) public mapWeekPool_Weight;   // Perls in each pool, per week
  mapping(uint => mapping(address => uint)) public mapWeekPool_Share;   // Share of reward for each pool, per week
  mapping(uint => mapping(address => uint)) public mapWeekPool_Claims; // Total LP tokens locked for each pool, per week

  uint public memberCount;
  address[] public arrayMembers;
  mapping(address => bool) public isMember;       // Is Member
  mapping(address => uint) public memberLock;     // Stops flash attacks
  mapping(address => uint) public mapMember_poolCount;        // Total number of Pools member is in
  mapping(address => address[]) public mapMember_arrayPools;  // Array of pools for member
  mapping(address => mapping(address => uint)) public mapMemberPool_Balance;      // Member's balance in pool
  mapping(address => mapping(address => bool)) public mapMemberPool_Added;        // Member's balance in pool
  mapping(address => mapping(uint => mapping(address => uint))) public mapMemberWeekPool_Claim;       // Value of claim per pool, per week
  mapping(address => mapping(uint => bool)) public mapMemberWeek_hasClaimed;  // Boolean claimed

  // Only Admin can execute
    modifier onlyAdmin() {
        require(msg.sender == perlinAdmin, "Must be Admin");
        _;
    }
  // FlashProof - modify method that adds balance
    modifier flashProof() {
        memberLock[msg.sender] = block.number;
        _;
    }
  // FlashSafe - modify method to prevent flash attack
    modifier flashSafe() {
        require(memberLock[msg.sender] < block.number, "Must be in previous block");
        _;
    }

  constructor(address perlin) public {
    perlinAdmin = msg.sender;
    PERL = perlin; //0xBEb8BE6b3E1051a50487517024263119F917cF88;
    WEEKS = 10;
    currentWeek = 1;
  }

  //==============================ADMIN================================//

  // Can be used to increase/decrease time period to give out rewards
  function updateConstants(uint rewardWeeks) public onlyAdmin {
    WEEKS = rewardWeeks;
  }
  // Add more incentives
  function addReward(uint amount) public onlyAdmin {
    TOTALREWARD += amount;
    ERC20(PERL).transferFrom(msg.sender, address(this), amount);
  }
  // Remove incentives (all, or some)
  function removeReward(uint amount)  public onlyAdmin {
    TOTALREWARD -= amount;
    ERC20(PERL).transfer(msg.sender, amount);
  }

  function listPool(address pool, uint factor) public onlyAdmin {
    if(!poolWasListed[pool]){
      arrayPerlinPools.push(pool);
      poolCount += 1;
    }
    poolIsListed[pool] = true;
    poolWasListed[pool] = true;
    poolFactor[pool] = factor; // Note: factor of 121 = 1.21
  }
  function delistPool(address pool) public onlyAdmin {
    poolIsListed[pool] = false;
  }
  function transferAdmin(address newAdmin) public onlyAdmin {
    perlinAdmin = newAdmin;
  }

// Snapshot a new Week
 function snapshotPools() public onlyAdmin {
    snapshotPoolsOnWeek(currentWeek);     // Snapshots PERL balances
    currentWeek += 1;                     // Increment the weekCount, so users can't register in a previous week.
 }
 // Use in anger re-snapshot a selected week
  function snapshotPoolsOnWeek(uint week) public onlyAdmin {
    // First snapshot balances of each pool
    uint perlTotal;
    for(uint i = 0; i<poolCount; i++){
      address pool = arrayPerlinPools[i];
      if(poolIsListed[pool] && poolHasMembers[pool]){
        uint factor = poolFactor[pool];
        uint perlBalance = (ERC20(PERL).balanceOf(pool).mul(factor)).div(100);  // (depth * factor) / 100
        perlTotal += perlBalance;
        mapWeekPool_Weight[week][pool] = perlBalance;
      }
    }
    mapWeek_Total[week] = perlTotal;
    // Then snapshot share of the reward for the week
    uint rewardForWeek = getRewardForWeek();
    for(uint i = 0; i<poolCount; i++){
      address pool = arrayPerlinPools[i];
      if(poolIsListed[pool] && poolHasMembers[pool]){
        uint part = mapWeekPool_Weight[week][pool];
        uint total = mapWeek_Total[week];
        mapWeekPool_Share[week][pool] = getShare(part, total, rewardForWeek);
      }
    }
    // Note, due to EVM gas limits, poolCount should be less than 100 to do this safely
  }
  function getRewardForWeek() public view returns(uint reward){
    return getShare(1, WEEKS, TOTALREWARD);
  }

  //==============================USER================================//
  function lock(address pool, uint amount) public flashProof {
    require(poolIsListed[pool] == true, "Must be listed");
    if(!isMember[msg.sender]){
      memberCount += 1;
      arrayMembers.push(msg.sender);
      isMember[msg.sender] = true;
    }
    if(!poolHasMembers[pool]){
      poolHasMembers[pool] = true;
    }
    if(!mapMemberPool_Added[msg.sender][pool]){                       // Record all the pools member is in
      mapMember_poolCount[msg.sender] += 1;
      mapMember_arrayPools[msg.sender].push(pool);
      mapMemberPool_Added[msg.sender][pool] = true;
    }
    mapMemberPool_Balance[msg.sender][pool] += amount;                // Record total pool balance for member
    registerClaim(msg.sender, pool, amount);                                 // Register claim
    ERC20(pool).transferFrom(msg.sender, address(this), amount);
  }
  function registerClaim(address member, address pool, uint amount) internal {
    mapMemberWeekPool_Claim[member][currentWeek][pool] += amount;
    mapWeekPool_Claims[currentWeek][pool] += amount;
  }
  function registerAllClaims(address member) public {
    for(uint i = 0; i < mapMember_poolCount[member]; i++){
      address pool = mapMember_arrayPools[member][i];
      uint amount = mapMemberPool_Balance[member][pool];
      registerClaim(member, pool, amount);
    }
  }

  function unlock(address pool) public flashSafe {
    uint balance = mapMemberPool_Balance[msg.sender][pool];
    if(balance > 0){
      mapMemberPool_Balance[msg.sender][pool] = 0;      // Zero out balance
      ERC20(pool).transfer(msg.sender, balance);        // Then transfer
    }
    if(ERC20(pool).balanceOf(address(this)) == 0){
      poolHasMembers[pool] = false;                       // If nobody is staking any more
    }
  }

  function claim(uint week) public flashSafe {
    require(mapMemberWeek_hasClaimed[msg.sender][week] == false, "Must not have claimed");
    uint totalClaim = checkClaim(msg.sender, week);
    if(totalClaim > 0){
      zeroOutClaims(msg.sender, week);
      mapMemberWeek_hasClaimed[msg.sender][week] = true;      // Register claim
      ERC20(PERL).transfer(msg.sender, totalClaim);           // Then transfer
    }
    registerAllClaims(msg.sender);                            // Register another claim
  }

  function checkClaim(address member, uint week) public view returns (uint totalClaim){
    for(uint i = 0; i < mapMember_poolCount[member]; i++){
      address pool = mapMember_arrayPools[member][i];
      totalClaim += checkClaimInPool(member, week, pool);
    }
    return totalClaim;
  }

  function checkClaimInPool(address member, uint week, address pool) public view returns (uint claimShare){
    uint poolShare = mapWeekPool_Share[week][pool];                           // Requires admin snapshotting for week first, else 0
    uint memberClaimInWeek = mapMemberWeekPool_Claim[member][week][pool];     // Requires member registering claim in the week
    uint totalClaimsInWeek = mapWeekPool_Claims[week][pool];
    if(totalClaimsInWeek > 0){                                                   // Requires non-zero balance of the pool tokens
      claimShare = getShare(memberClaimInWeek, totalClaimsInWeek, poolShare);
    } else {
      claimShare = 0;
    }
    return claimShare;
  }

  function zeroOutClaims(address member, uint week) internal {
    for(uint i = 0; i < mapMember_poolCount[member]; i++){
      address pool = mapMember_arrayPools[member][i];
      mapMemberWeekPool_Claim[member][week][pool] = 0;
    }
  }

  //==============================UTILS================================//
  function getShare(uint part, uint total, uint amount) public pure returns (uint share){
      return (amount.mul(part)).div(total);
  }
}
