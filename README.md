## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```





chinmaisiddhartha@Chinmais-MacBook-Air balancer-fl % hh test --network hardhat


  Arbitrage
    deployment
Arbitrage contract address: 0x810090f35DFA6B18b5EB59d298e2A2443a2811E2
      ✔ should deploy the contract (6693ms)
checking WETH balance of our smart contract..!!
WETH balance of our smart contract before swap is: 2000000000000000000
Balance before flashloan:  2000000000000000000
FlashLoan received:  3000000000000000000
Executing arbitrage...
Executing arbitrage on exchange:  1
Placing swap on exchange:  1
tokenIn balance of smart contract before swap: 3000000000000000000
tokenOut balance of smart contract before swap: 0

amountOutMin v3: 46128069051115779218647335095000000000000000
SwapExactInputSingle - Pool Address: 0x2e4784446a0a06df3d1a040b03e1680ee266c35a
zero for one : false
V3 Swap - Token In: 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2

V3 Swap - token0:  0x4e3fbd56cd56c3e72c1403e103b45db9da5b9d2b
V3 Swap - token1:  0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
swap executed on exchange: 1
tokenIn balance of smart contract after swap: 2999513153400089967
tokenOut balance of smart contract after swap: 821637672973576498
Swap completed. Amount in:  1000000000000000000  Amount out:  821637672973576498
Executing arbitrage on exchange:  0
Placing swap on exchange:  0
tokenIn balance of smart contract before swap: 821637672973576498
tokenOut balance of smart contract before swap: 2999513153400089967

expected amountOut: 496499822604478
amountOutMin: 495258573047966
V2 Swap - Path: 0x4e3fbd56cd56c3e72c1403e103b45db9da5b9d2b 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
path0 contract balance is :  821637672973576498
path1 contract balance is :  2999513153400089967
V2 Swap - Token balance before approval: 821637672973576498
V2 Swap - Approving tokens for transfer...
V2 Swap - Approval allowance: 821637672973576498
V2 Swap - Actual Amount In: 821637672973576498
V2 Swap - Actual Amount Out: 496499822604478
swap executed on exchange: 0
tokenIn balance of smart contract after swap: 0
tokenOut balance of smart contract after swap: 3000009653222694445
Swap completed. Amount in:  821637672973576498  Amount out:  496499822604478
Final amount:  496499822604478  Flash loan amount:  1000000000000000000
No profit. Final amount:  496499822604478  Flash loan amount:  1000000000000000000
Arbitrage transaction: ContractTransactionResponse {
  provider: HardhatEthersProvider {
    _hardhatProvider: LazyInitializationProviderAdapter {
      _providerFactory: [AsyncFunction (anonymous)],
      _emitter: [EventEmitter],
      _initializingPromise: [Promise],
      provider: [BackwardsCompatibilityProviderAdapter]
    },
    _networkName: 'hardhat',
    _blockListeners: [],
    _transactionHashListeners: Map(0) {},
    _eventListeners: []
  },
  blockNumber: 21142148,
  blockHash: '0x038a719cb4be243c68246817944bafe5a42c382f697cae664942b92c81c954c0',
  index: undefined,
  hash: '0xe8bb876092430fdc1bb3ba7a4eec812de7d58151e04c013c067475d39ee2eaec',
  type: 2,
  to: '0x810090f35DFA6B18b5EB59d298e2A2443a2811E2',
  from: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
  nonce: 798,
  gasLimit: 30000000n,
  gasPrice: 7549774900n,
  maxPriorityFeePerGas: 1000000000n,
  maxFeePerGas: 14099549800n,
  maxFeePerBlobGas: null,
  data: '0x1c5318e4000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000de0b6b3a764000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000003000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000004e3fbd56cd56c3e72c1403e103b45db9da5b9d2b000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000002e4784446a0a06df3d1a040b03e1680ee266c35a00000000000000000000000005767d9ef41dc40689678ffca0608878fb3de906',
  value: 0n,
  chainId: 31337n,
  signature: Signature { r: "0x3c3b0c14d855e503af292adf1ea26e8ade47a6372864910ce6bfb3b017f790b2", s: "0x251c96bd4f3390d84a694dd9fb6e1d35adc818f0095c214b8f2d112238699ca8", yParity: 0, networkV: null },
  accessList: [],
  blobVersionedHashes: null
}
checking WETH balance of our smart contract after swap..!!
WETH balance of our smart contract after the swap is: 2000009653222694445
      ✔ should attempt flashloan and arbitrage (12304ms)


  2 passing (19s)

chinmaisiddhartha@Chinmais-MacBook-Air balancer-fl % 