# MerkleWhitelistNFT Contract

This is a Solidity smart contract for a Merkle Tree-based whitelist NFT minting system. It allows users to mint NFTs at different prices based on whether they are on a whitelist (controlled by a Merkle Tree) or not. The contract also supports royalties via IERC2981 and includes functionality for contract and token metadata URIs.

## Overview

The `MerkleWhitelistNFT` contract is an ERC-721 based NFT implementation with the following features:

- **Merkle Tree-based Whitelist**: Users can mint NFTs at a discounted price if they are part of the whitelist, verified using a Merkle Tree.
- **Public Minting**: Users who are not whitelisted can still mint NFTs at a higher public price.
- **Royalty Support**: The contract implements IERC2981 to ensure royalties are distributed on secondary sales.
- **Metadata Support**: Customizable contract URI and token URI for NFTs.
- **Owner Withdrawal**: The contract owner can withdraw funds collected from minting.
- **Royalties**: Supports royalty payments when NFTs are sold on secondary markets.

### 1. Installation

To use or deploy this contract, you'll need the following tools:
**Foundry**: fast and efficient Ethereum development framework.
   
Follow these steps to use Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Clone the Repository
Clone this repository to your local machine:

```bash
git clone <your-repository-url>
cd <your-repository-folder>
```

### 3. Install Dependencies
After navigating to the project folder, install the necessary dependencies:

```bash
forge install
```

### 4. Compile the Contract
To compile the contract, run:

```bash
forge build
```

### 5. Run Tests
To run the tests, execute:

```bash
forge test
```

### 6. Coverage
To check the code coverage, run:

```bash
forge coverage
```

### Withdraw Funds
The owner can withdraw all accumulated funds from the contract using the `withdraw` function.

### Merkle Proof Generation
For off-chain Merkle Proof generation, you can use libraries like [murky](https://github.com/dmfxyz/murky) or [merkletreejs](https://github.com/miguelmota/merkletreejs).
