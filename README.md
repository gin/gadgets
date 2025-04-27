## Gadgets
The smart contracts have their corresponding tests in the `test/` directory.

| File                                         | Description                                                             |
|----------------------------------------------|-------------------------------------------------------------------------|
| [CommunityChest.sol](src/CommunityChest.sol) | An update to the smart contract from [#communitychest](#communitychest) |
| [TipJar.sol](src/TipJar.sol)                 | An update to the smart contract from [#tipjar](#tipjar)                 |

[communitychest]: https://programtheblockchain.com/posts/2017/12/15/writing-a-contract-that-handles-ether/
[tipjar]: https://programtheblockchain.com/posts/2017/12/26/checking-the-sender-in-a-smart-contract/

### Notes
Show which functions are not tested
```sh
forge coverage --report lcov && genhtml lcov.info -o coverage
```

Show which branches are not tested
```sh
forge coverage --report debug
```
