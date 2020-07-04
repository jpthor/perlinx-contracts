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

  mapping(address => bool) public poolIsListed;
  mapping(address => bool) public poolWasListed;
  // mapping(address => uint) public balancePool;
  mapping(uint => uint) public mapWeek_Total;
  mapping(uint => mapping(address => uint)) public mapWeekPool_Perls; // Perls in each pool
  mapping(uint => mapping(address => uint)) public mapWeekPool_Share; // Share of reward for each pool
  mapping(uint => mapping(address => uint)) public mapWeekPool_Balance; // Total LP tokens locked for each pool

  uint public memberCount;
  address[] public arrayMembers;
  mapping(address => uint) public mapMember_blockLastLocked;
  mapping(address => uint) public mapMember_weekLastLocked;
  mapping(address => mapping(uint => mapping(address => uint))) public mapMemberWeekPool_Claim;
  mapping(address => mapping(address => uint)) public mapMemberPool_Balance;
  mapping(address => mapping(uint => mapping(address => bool))) public mapMemberWeekPool_hasClaimed;

  // Only Admin can execute
    modifier onlyAdmin() {
        require(msg.sender == perlinAdmin, "Must be Admin");
        _;
    }

  constructor(address perlin) public {
    perlinAdmin = msg.sender;
    PERL = perlin;
    WEEKS = 10;
    currentWeek = 1;
  }

  //==============================ADMIN================================//

  function updateConstants(uint rewardWeeks) public onlyAdmin {
    WEEKS = rewardWeeks;
  }

  function addReward(uint amount) public onlyAdmin {
    TOTALREWARD += amount;
    ERC20(PERL).transferFrom(msg.sender, address(this), amount);
  }

  function removeReward(uint amount)  public onlyAdmin {
    TOTALREWARD = TOTALREWARD.sub(amount);
    ERC20(PERL).transfer(msg.sender, amount);
  }

  function listPool(address pool) public onlyAdmin {
    if(!poolWasListed[pool]){
      arrayPerlinPools.push(pool);
    }
    poolIsListed[pool] = true;
    poolWasListed[pool] = true;
    poolCount += 1;
  }
  function delistPool(address pool) public onlyAdmin {
    poolIsListed[pool] = false;
    poolCount -= 1;
  }

// Snapshot a new Week
 function snapshotPools() public onlyAdmin {
    snapshotPoolsOnWeek(currentWeek);
    currentWeek += 1;
 }
 // Use in anger re-snapshot a selected week
  function snapshotPoolsOnWeek(uint week) public onlyAdmin {
    // First snapshot balances of each pool
    uint perlTotal;
    for(uint i = 0; i<poolCount; i++){
      address pool = arrayPerlinPools[i];
      if(poolIsListed[pool]){
        uint perlBalance = ERC20(PERL).balanceOf(pool);
        perlTotal += perlBalance;
        mapWeekPool_Perls[week][pool] = perlBalance;
      }
    }
    mapWeek_Total[week] = perlTotal;
    // Then snapshot share of the reward for the week
    uint amount = getShare(1, WEEKS, TOTALREWARD);
    for(uint i = 0; i<poolCount; i++){
      address pool = arrayPerlinPools[i];
      if(poolIsListed[pool]){
        uint part = mapWeekPool_Perls[week][pool];
        uint total = mapWeek_Total[week];
        mapWeekPool_Share[week][pool] = getShare(part, total, amount);
      }
    }
    // Note, due to EVM gas limits, poolCount should be less than 100 to do this
  }

  //==============================USER================================//
  function lock(address pool, uint amount) public {
    require(poolIsListed[pool] == true, "Must be listed");
    mapMember_blockLastLocked[msg.sender] = block.number;             // Prevents flash-attacks
    mapMemberPool_Balance[msg.sender][pool] += amount;                // Record total pool balance for member
    mapWeekPool_Balance[currentWeek][pool] += amount;                 // Record total pool balance in week
    registerClaimInCurrentWeek(pool);
    ERC20(pool).transferFrom(msg.sender, address(this), amount);
  }

   function unlock(address pool) public {
    uint balance = mapMemberPool_Balance[msg.sender][pool];
    safetyCheck(msg.sender);
    if(balance > 0){
      ERC20(pool).transfer(msg.sender, balance);
      mapMemberPool_Balance[msg.sender][pool] = 0;
    }
  }

  function claim(uint week, address pool) public {
    require(mapMemberWeekPool_hasClaimed[msg.sender][week][pool] == false, "Must not have claimed");
    require(mapMemberPool_Balance[msg.sender][pool] > 0, "Must still be member in pool");
    safetyCheck(msg.sender);
    registerClaimInCurrentWeek(pool);
    uint claimShare = checkClaim(msg.sender, week, pool);
    mapMemberWeekPool_hasClaimed[msg.sender][week][pool] = true;
    ERC20(PERL).transfer(msg.sender, claimShare);
  }

  function registerClaimInCurrentWeek(address pool) public {
    mapMemberWeekPool_Claim[msg.sender][currentWeek][pool] = mapMemberPool_Balance[msg.sender][pool];
  }

  function checkClaim(address member, uint week, address pool) public view returns (uint claimShare){
    uint poolShare = mapWeekPool_Share[week][pool];
    uint memberClaimInWeek = mapMemberWeekPool_Claim[member][week][pool];
    uint totalBalInWeek = mapWeekPool_Balance[week][pool];
    if(totalBalInWeek > 0){
      claimShare = getShare(memberClaimInWeek, totalBalInWeek, poolShare);
    } else {
      claimShare = 0;
    }
    return claimShare;
  }

  //==============================UTILS================================//
  function getShare(uint part, uint total, uint amount) public pure returns (uint share){
      return (amount.mul(part)).div(total);
  }
  function safetyCheck(address _member) internal view {
    require(mapMember_blockLastLocked[_member] < block.number, "Must be in previous block");
  }
}
