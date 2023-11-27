## OnChainRFQSystem.sol
A contract that runs RFQ (request for quote) auctions onchain without trusted third parties. It uses a commit-reveal scheme to hide bids until the auction ends and returns the best quote. A possible integration may use the winning quote in conjunction with other quotes to parametize a swap, giving preferential treatment to the winning quoter.

This is best used on an L2 where block times are short and gas costs are low. 

DISCLAIMER: This is a work in progress and has not been audited. Use at your own risk.

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
