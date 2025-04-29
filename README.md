## Gadgets
Gadgets are small and fun smart contracts.

I'm updating my Solidity and Vyper knowledge by updating and porting smart contracts I found interesting from around the internet.  
Solidity contracts are in the `src/` directory, and are using features and best practices from 0.8.27 (e.g. Custom Errors in require)  
Vyper contracts are in the `src/` directory, and are using features and best practices from 0.4.1

The smart contracts have their corresponding tests in the `test/` directory.  
Run `forge test` to run the Solidity tests. ([Foundry installation])  
Run `mox test` to run the Vyper tests.  ([Moccasin installation])

| File                                         | Description                                                                  |
|----------------------------------------------|------------------------------------------------------------------------------|
| [CommunityChest.sol](src/CommunityChest.sol) | An update to the smart contract from [programtheblockchain's CommunityChest] |
| [TipJar.sol](src/TipJar.sol)                 | An update to the smart contract from [programtheblockchain's TipJar]         |
| [Bank.sol](src/Bank.sol)                     | An update to the smart contract from [programtheblockchain's Bank]           |

[Foundry installation]: https://book.getfoundry.sh/getting-started/installation
[Moccasin installation]: https://cyfrin.github.io/moccasin/installing_moccasin.html
[programtheblockchain's CommunityChest]: https://programtheblockchain.com/posts/2017/12/15/writing-a-contract-that-handles-ether/
[programtheblockchain's TipJar]: https://programtheblockchain.com/posts/2017/12/26/checking-the-sender-in-a-smart-contract/
[programtheblockchain's Bank]: https://programtheblockchain.com/posts/2018/01/05/writing-a-banking-contract/
[programtheblockchain's Savings]: https://programtheblockchain.com/posts/2018/01/12/writing-a-contract-that-handles-time/
[programtheblockchain's Crowdfunding]: https://programtheblockchain.com/posts/2018/01/19/writing-a-crowdfunding-contract-a-la-kickstarter/
[programtheblockchain's Multicounter]: https://programtheblockchain.com/posts/2018/01/24/logging-and-watching-solidity-events/
[programtheblockchain's MinimalToken]: https://programtheblockchain.com/posts/2018/01/26/what-is-an-ethereum-token/
[programtheblockchain's SimpleERC20Token]: https://programtheblockchain.com/posts/2018/01/30/writing-an-erc20-token-contract/

### Notes
Show which functions are not tested
```sh
forge coverage --report lcov && genhtml lcov.info -o coverage
```

Show which branches are not tested
```sh
forge coverage --report debug
```
