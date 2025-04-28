## Gadgets
The smart contracts have their corresponding tests in the `test/` directory.

| File                                         | Description                                                             |
|----------------------------------------------|-------------------------------------------------------------------------|
| [CommunityChest.sol](src/CommunityChest.sol) | An update to the smart contract from [#communitychest](#communitychest) |
| [TipJar.sol](src/TipJar.sol)                 | An update to the smart contract from [#tipjar](#tipjar)                 |
| [Bank.sol](src/Bank.sol)                     | An update to the smart contract from [#bank](#bank)                     |

[communitychest]: https://programtheblockchain.com/posts/2017/12/15/writing-a-contract-that-handles-ether/
[tipjar]: https://programtheblockchain.com/posts/2017/12/26/checking-the-sender-in-a-smart-contract/
[bank]: https://programtheblockchain.com/posts/2018/01/05/writing-a-banking-contract/
[savings]: https://programtheblockchain.com/posts/2018/01/12/writing-a-contract-that-handles-time/
[crowdfunding]: https://programtheblockchain.com/posts/2018/01/19/writing-a-crowdfunding-contract-a-la-kickstarter/
[multicounter]: https://programtheblockchain.com/posts/2018/01/24/logging-and-watching-solidity-events/
[minimaltoken]: https://programtheblockchain.com/posts/2018/01/26/what-is-an-ethereum-token/
[simpleerc20token]: https://programtheblockchain.com/posts/2018/01/30/writing-an-erc20-token-contract/

### Notes
Show which functions are not tested
```sh
forge coverage --report lcov && genhtml lcov.info -o coverage
```

Show which branches are not tested
```sh
forge coverage --report debug
```
