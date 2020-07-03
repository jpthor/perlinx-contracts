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
  uint public TIME;
  uint public poolCount;
  uint public eraCount;

  mapping(address => bool) public poolIsListed;
  mapping(address => bool) public poolWasListed;
  mapping(address => uint) public balancePool;
  mapping(uint => uint) public mapEra_Total;
  mapping(uint => mapping(address => uint)) public mapEraPool_Balance;
  mapping(uint => mapping(address => uint)) public mapEraPool_Share;

  uint public memberCount;
  address[] public arrayMembers;
  mapping(address => uint) public mapMember_timeLastLocked;
  mapping(address => mapping(address => uint)) public mapMemberPool_Balance;
  mapping(address => mapping(uint => mapping(address => bool))) public mapMemberEraPool_hasClaimed;

  // Only Admin can execute
    modifier onlyAdmin() {
        require(msg.sender == perlinAdmin, "Must be Admin");
        _;
    }

  constructor(address perlin) public {
    perlinAdmin = msg.sender;
    PERL = perlin;
    WEEKS = 11;
    TIME =1;
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

  function snapshotPools(uint era) public onlyAdmin {
    // First snapshot balances of each pool
    if(era > eraCount){
      eraCount += 1;
    }
    uint perlTotal;
    for(uint i = 0; i<poolCount; i++){
      address pool = arrayPerlinPools[i];
      if(poolIsListed[pool]){
        uint perlBalance = ERC20(PERL).balanceOf(pool);
        perlTotal += perlBalance;
        mapEraPool_Balance[era][pool] = perlBalance;
      }
    }
    mapEra_Total[era] = perlTotal;
    // Then snapshot share of the reward for the week
    uint amount = getShare(1, WEEKS, TOTALREWARD);
    for(uint i = 0; i<poolCount; i++){
      address pool = arrayPerlinPools[i];
      if(poolIsListed[pool]){
        uint part = mapEraPool_Balance[era][pool];
        uint total = mapEra_Total[era];
        mapEraPool_Share[era][pool] = getShare(part, total, amount);
      }
    }
    // Note, due to EVM gas limits, poolCount should be less than 100 to do this
  }

  //==============================USER================================//
  function lock(address pool, uint amount) public {
    require(poolIsListed[pool] == true, "Must be listed");
    mapMember_timeLastLocked[msg.sender] = now;
    ERC20(pool).transferFrom(msg.sender, address(this), amount);
    balancePool[pool] += amount;
    mapMemberPool_Balance[msg.sender][pool] += amount;
  }

   function unlock(address pool) public {
    uint balance = mapMemberPool_Balance[msg.sender][pool];
    safetyCheck(msg.sender);
    if(balance > 0){
      ERC20(pool).transfer(msg.sender, balance);
      balancePool[pool] = balancePool[pool].sub(balance);
      mapMemberPool_Balance[msg.sender][pool] = 0;
    }
  }

  function claim(uint era, address pool) public {
    require(mapMemberEraPool_hasClaimed[msg.sender][era][pool] == false, "Must not have claimed");
    safetyCheck(msg.sender);
    uint poolShare = mapEraPool_Share[era][pool];
    uint balanceOfMember = mapMemberPool_Balance[msg.sender][pool];
    uint totalBalance = balancePool[pool];
    uint claimShare = getShare(balanceOfMember, totalBalance, poolShare);
    mapMemberEraPool_hasClaimed[msg.sender][era][pool] = true;
    ERC20(PERL).transfer(msg.sender, claimShare);
  }

  //==============================UTILS================================//
  function getShare(uint part, uint total, uint amount) public returns (uint){
      return (amount.mul(part)).div(total);
  }
  function safetyCheck(address _member) internal view {
    require(mapMember_timeLastLocked[_member] <= now.sub(TIME), "Must be old enough");
  }
}
