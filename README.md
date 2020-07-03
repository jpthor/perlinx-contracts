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
function snapshotPools(uint era) public onlyAdmin
```


### User Functions
```solidity
function lock(address pool, uint amount) public
function unlock(address pool) public
function claim(uint era, address pool) public
```


## Testing

```
yarn
npx buidler test
```