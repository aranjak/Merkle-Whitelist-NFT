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
