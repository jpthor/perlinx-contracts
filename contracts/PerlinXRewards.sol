//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@nomiclabs/buidler/console.sol";

// ERC20 Interface
interface ERC20 {
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
// Uniswap Interface
interface UNISWAP {
    function token0() external returns (address);
    function token1() external returns (address);
}
// EMP Interface
interface EMP {
    function tokenCurrency() external returns (address);
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

  address public PERL;
  address[] public arrayAdmins;
  uint public adminCount;
  address[] public arrayPerlinPools;
  uint public poolCount;
  address[] public arraySynths;
  uint public synthCount;
  address[] public arrayMembers;
  uint public memberCount;

  uint public WEEKS;
  uint public TOTALREWARDS;
  uint public currentWeek;

  mapping(address => bool) public isAdmin;       // Tracks admin status
  mapping(address => bool) public poolIsListed;       // Tracks current listing status
  mapping(address => bool) public poolHasMembers;       // Tracks current staking status
  mapping(address => bool) public poolWasListed;      // Tracks if pool was ever listed
  mapping(address => uint) public poolWeight;         // Allows a reward weight to be applied; 100 = 1.0
  mapping(uint => uint) public mapWeek_Total;         // Total PERL staked in each week
  mapping(uint => mapping(address => uint)) public mapWeekPool_Weight;   // Perls in each pool, per week
  mapping(uint => mapping(address => uint)) public mapWeekPool_Share;   // Share of reward for each pool, per week
  mapping(uint => mapping(address => uint)) public mapWeekPool_Claims; // Total LP tokens locked for each pool, per week

  mapping(address => address) public mapPool_Asset; // Uniswap pools provide liquidity to non-PERL asset
  mapping(address => address) public mapSynth_EMP;  // Synthetic Assets have a management contract

  mapping(address => bool) public isMember;       // Is Member
  mapping(address => uint) public memberLock;     // Stops flash attacks
  mapping(address => uint) public mapMember_poolCount;        // Total number of Pools member is in
  mapping(address => address[]) public mapMember_arrayPools;  // Array of pools for member
  mapping(address => mapping(address => uint)) public mapMemberPool_Balance;      // Member's balance in pool
  mapping(address => mapping(address => bool)) public mapMemberPool_Added;        // Member's balance in pool
  mapping(address => mapping(uint => mapping(address => uint))) public mapMemberWeekPool_Claim;       // Value of claim per pool, per week
  mapping(address => mapping(uint => bool)) public mapMemberWeek_hasClaimed;  // Boolean claimed

  event Snapshot(address admin, uint week, uint rewardForWeek, uint perlTotal, uint validPoolCount, uint validMemberCount);
  event AddReward(address admin, uint amount, uint newTotal);
  event RemoveReward(address admin, uint amount, uint newTotal);
  event NewPool(address admin, address pool, address asset, uint assetWeight);
  event NewSynth(address synth, address expiringMultiParty);
  event MemberLocks(address admin, address pool, uint amount, uint currentWeek);
  event MemberUnlocks(address member, address pool, uint currentWeek);
  event MemberRegisters(address member, address pool, uint amount, uint currentWeek);
  event MemberClaims(address member, uint week, uint totalClaim);

  // Only Admin can execute
    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Must be Admin");
        _;
    }

  // FlashProof - modify in method that initiates state change, typically funds deposit
    modifier flashProof() {
        memberLock[msg.sender] = block.number;
        _;
    }
  // FlashSafe - modify method to prevent flash attack, typically funds withdrawal
    modifier flashSafe() {
        require(memberLock[msg.sender] < block.number, "Must be in previous block");
        _;
    }

  constructor(address perlin) public {
    arrayAdmins.push(msg.sender);
    adminCount = 1;
    isAdmin[msg.sender] = true;
    PERL = perlin; //0xB7b9568073C9e745acD84eEb30F1c32F74Ba4946;
    currentWeek = 1;
  }
  //==============================ADMIN================================//

  // Add more incentives
  function addReward(uint amount) public onlyAdmin {
    TOTALREWARDS += amount;
    ERC20(PERL).transferFrom(msg.sender, address(this), amount);
    emit AddReward(msg.sender, amount, TOTALREWARDS);
  }
  // Remove incentives (all, or some)
  function removeReward(uint amount)  public onlyAdmin {
    TOTALREWARDS -= amount;
    ERC20(PERL).transfer(msg.sender, amount);
    emit RemoveReward(msg.sender, amount, TOTALREWARDS);
  }

  // Lists a synth and its parent EMP address
  function listSynth(address pool, address synth, address emp, uint weight) public onlyAdmin {
    require(EMP(emp).tokenCurrency() == synth, "Must be the correct asset");
    if(!poolWasListed[pool]){
      arraySynths.push(synth);          // Add new synth
      synthCount += 1;                  // Count it
    }
    listPool(pool, synth, weight);      // List like normal pool
    mapSynth_EMP[synth] = emp;          // Maps the EMP contract for look-up
    emit NewSynth(synth, emp);
  }
  // Lists a pool and its non-PERL asset
  function listPool(address pool, address asset, uint weight) public onlyAdmin {
    require((UNISWAP(pool).token0() == PERL || UNISWAP(pool).token1() == PERL), "Must be PERL pool");
    require((UNISWAP(pool).token0() == asset || UNISWAP(pool).token1() == asset), "Must also have asset in pool");
    require(asset != PERL, "Must not be PERL");
    require(weight >= 1 && weight <= 1000, "Must be greater than 0.1, less than 10");
    if(!poolWasListed[pool]){
      arrayPerlinPools.push(pool);
      poolCount += 1;
    }
    poolIsListed[pool] = true;  // Tracking listing
    poolWasListed[pool] = true;   // Track if ever was listed
    poolWeight[pool] = weight; // Note: weight of 121 = 1.21
    mapPool_Asset[pool] = asset; // Map the pool to its non-perl asset
    emit NewPool(msg.sender, pool, asset, weight);
  }

  function delistPool(address pool) public onlyAdmin {
    poolIsListed[pool] = false;
  }

  function addAdmin(address newAdmin) public onlyAdmin {
    arrayAdmins.push(newAdmin);
    adminCount += 1;
    isAdmin[newAdmin] = true;
  }
  function transferAdmin(address newAdmin) public onlyAdmin {
    isAdmin[newAdmin] = true;
    isAdmin[msg.sender] = false;
  }

// Snapshot a new Week
 function snapshotPools(uint reward) public onlyAdmin {
    require(reward > 0, "Must be non-zero");
    require(reward <= ERC20(PERL).balanceOf(address(this)), "Must be less than available");
    snapshotPoolsOnWeek(currentWeek, reward);     // Snapshots PERL balances
    currentWeek += 1;                     // Increment the weekCount, so users can't register in a previous week.
 }
  // Use in anger re-snapshot a selected week
  // Note, due to EVM gas limits, poolCount should be less than 100 to do this safely
  function snapshotPoolsOnWeek(uint week, uint rewardForWeek) public onlyAdmin {
    // First snapshot balances of each pool
    uint perlTotal; uint validPoolCount; uint validMemberCount;
    for(uint i = 0; i<poolCount; i++){
      address pool = arrayPerlinPools[i];
      if(poolIsListed[pool] && poolHasMembers[pool]){
        validPoolCount += 1;
        uint weight = poolWeight[pool];
        uint perlBalance = (ERC20(PERL).balanceOf(pool).mul(weight)).div(100);  // (depth * weight) / 100
        perlTotal += perlBalance;
        mapWeekPool_Weight[week][pool] = perlBalance;
      }
    }
    mapWeek_Total[week] = perlTotal;
    // Then snapshot share of the reward for the week
    for(uint i = 0; i<poolCount; i++){
      address pool = arrayPerlinPools[i];
      if(poolIsListed[pool] && poolHasMembers[pool]){
        validMemberCount += 1;
        uint part = mapWeekPool_Weight[week][pool];
        uint total = mapWeek_Total[week];
        mapWeekPool_Share[week][pool] = getShare(part, total, rewardForWeek);
      }
    }
    emit Snapshot(msg.sender, week, rewardForWeek, perlTotal, validPoolCount, validMemberCount);
  }

  //============================== USER - LOCK/UNLOCK ================================//
  // Member locks some LP tokens
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
    emit MemberLocks(msg.sender, pool, amount, currentWeek);
  }

  // Member unlocks all from a pool
  function unlock(address pool) public flashSafe {
    uint balance = mapMemberPool_Balance[msg.sender][pool];
    if(balance > 0){
      mapMemberPool_Balance[msg.sender][pool] = 0;      // Zero out balance
      ERC20(pool).transfer(msg.sender, balance);        // Then transfer
    }
    if(ERC20(pool).balanceOf(address(this)) == 0){
      poolHasMembers[pool] = false;                       // If nobody is staking any more
    }
    emit MemberUnlocks(msg.sender, pool, currentWeek);
  }

  //============================== USER - CLAIM================================//
    // Member registers claim in a single pool
  function registerClaim(address member, address pool, uint amount) internal {
    mapMemberWeekPool_Claim[member][currentWeek][pool] += amount;
    mapWeekPool_Claims[currentWeek][pool] += amount;
    emit MemberRegisters(member, pool, amount, currentWeek);
  }
  // Member registers claim in all pools
  function registerAllClaims(address member) public {
    for(uint i = 0; i < mapMember_poolCount[member]; i++){
      address pool = mapMember_arrayPools[member][i];
      uint amount = mapMemberPool_Balance[member][pool];
      registerClaim(member, pool, amount);
    }
  }
  // Member claims in a week
  function claim(uint week) public flashSafe {
    require(mapMemberWeek_hasClaimed[msg.sender][week] == false, "Must not have claimed");
    uint totalClaim = checkClaim(msg.sender, week);
    if(totalClaim > 0){
      zeroOutClaims(msg.sender, week);
      mapMemberWeek_hasClaimed[msg.sender][week] = true;      // Register claim
      ERC20(PERL).transfer(msg.sender, totalClaim);           // Then transfer
    }
    emit MemberClaims(msg.sender, week, totalClaim);
    registerAllClaims(msg.sender);                            // Register another claim
  }
  // Member checks claims in all pools
  function checkClaim(address member, uint week) public view returns (uint totalClaim){
    for(uint i = 0; i < mapMember_poolCount[member]; i++){
      address pool = mapMember_arrayPools[member][i];
      totalClaim += checkClaimInPool(member, week, pool);
    }
    return totalClaim;
  }
  // Member checks claim in a single pool
  function checkClaimInPool(address member, uint week, address pool) public view returns (uint claimShare){
    uint poolShare = mapWeekPool_Share[week][pool];                           // Requires admin snapshotting for week first, else 0
    uint memberClaimInWeek = mapMemberWeekPool_Claim[member][week][pool];     // Requires member registering claim in the week
    uint totalClaimsInWeek = mapWeekPool_Claims[week][pool];                  // Sum of all claims in a week
    if(totalClaimsInWeek > 0){                                                // Requires non-zero balance of the pool tokens
      claimShare = getShare(memberClaimInWeek, totalClaimsInWeek, poolShare);
    } else {
      claimShare = 0;
    }
    return claimShare;
  }
  // Internal function to zero out claims for a member in a week
  function zeroOutClaims(address member, uint week) internal {
    for(uint i = 0; i < mapMember_poolCount[member]; i++){
      address pool = mapMember_arrayPools[member][i];
      mapMemberWeekPool_Claim[member][week][pool] = 0;
    }
  }

  //==============================UTILS================================//
  // Get the share of a total
  function getShare(uint part, uint total, uint amount) public pure returns (uint share){
      return (amount.mul(part)).div(total);
  }
}
