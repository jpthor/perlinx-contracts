# PerlinX Rewards Contracts


Allows an admin to:
1) Add TOTALREWARDS
2) Specify number of weeks to run for (reward eras)
3) Curate select Uniswap Pools (and delist)
4) Snapshot the balances for a new Reward Era

Allows Users to:
1) Lock up Uniswap LP tokens - but only if curated
2) Claim rewards for a certan reward era 
3) Unlock Uniswap LP tokens

### Admin Functions
```solidity
function updateConstants(uint rewardWeeks) public onlyAdmin
function addReward(uint amount) public onlyAdmin
function removeReward(uint amount)  public onlyAdmin
function listPool(address pool) public onlyAdmin
function delistPool(address pool) public onlyAdmin
function transferAdmin(address newAdmin) public onlyAdmin
function snapshotPools(uint era) public onlyAdmin
function snapshotPoolsOnWeek(uint week) public onlyAdmin
```


### User Functions
```solidity
function lock(address pool, uint amount) public
function unlock(address pool) public
function claim(uint era, address pool) public
function registerClaimInCurrentWeek(address pool) public
function checkClaim(address member, uint week, address pool) public view returns (uint claimShare)
```


## Testing

```
yarn
npx buidler test
```



perlin deployed to: 0x7c2C195CD6D34B8F845992d380aADB2730bB9C6F
perlinX deployed to: 0x8858eeB3DfffA017D4BCE9801D340D36Cf895CCf
lp1 deployed to: 0x0078371BDeDE8aAc7DeBfFf451B74c5EDB385Af7
lp2 deployed to: 0xf4e77E5Da47AC3125140c470c71cBca77B5c638c