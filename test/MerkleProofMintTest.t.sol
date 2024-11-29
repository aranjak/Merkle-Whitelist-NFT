// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {MerkleWhitelistNFT} from "../src/MerkleWhitelistNFT.sol";
import {Merkle} from "@murky/contracts/Merkle.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract MerkleWhitelistNFTTest is Test {
    MerkleWhitelistNFT private nftContract;
    bytes32 private merkleRoot;
    address[] private whitelist;
    Merkle private merkle;
    bytes32[] private s_leaves;

    uint96 royaltyFee = 500; // 5% royalty
    uint256 whitelistPrice = 0.05 ether;
    uint256 publicPrice = 0.1 ether;
    string contractURI = "ipfs://contract-metadata";
    string baseTokenURI = "ipfs://base-token-uri/";
    string baseExtension = ".json";

    event RoyaltiesReceived(
        address indexed royaltyRecipient,
        address indexed buyer,
        uint256 indexed tokenId,
        address tokenPaid,
        uint256 amount,
        bytes32 metadata
    );

    function setUp() public {
        // Define a whitelist of addresses
        whitelist = new address[](6);
        whitelist[0] = address(0x456);
        whitelist[1] = address(0x123);
        whitelist[2] = address(0x789);
        whitelist[3] = address(0x111);
        whitelist[4] = address(0x222);
        whitelist[5] = address(0x333);

        // Generate Merkle Root
        bytes32[] memory leaves = new bytes32[](whitelist.length);
        for (uint256 i = 0; i < whitelist.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(whitelist[i]));
        }
        s_leaves = leaves;

        merkle = new Merkle();
        merkleRoot = merkle.getRoot(leaves);

        vm.prank(whitelist[0]); // Deploy by address(0x456)
        // Deploy the contract
        nftContract =
            new MerkleWhitelistNFT(merkleRoot, royaltyFee, whitelistPrice, publicPrice, contractURI, baseTokenURI);
    }

    function testTotalSupplyAfterDeployment() public view {
        // Check that the totalSupply is 0 after deployment
        uint256 totalSupply = nftContract.totalSupply();
        assertEq(totalSupply, 0, "Total supply should be 0 after deployment");
    }

    function testIsWhitelisted() public view {
        // Get proof
        bytes32[] memory proof = merkle.getProof(s_leaves, 5);
        // Execute isWhitelisted
        bool result = nftContract.isWhitelisted(whitelist[5], proof);
        // Assert whitelisted
        assertTrue(result, "Address should be whitelisted");
    }

    function testIsNotWhitelisted() public view {
        // Get proof
        bytes32[] memory proof = merkle.getProof(s_leaves, 5);
        // Execute isWhitelisted
        bool result = nftContract.isWhitelisted(address(0x999), proof);
        // Assert not whitelisted
        assertFalse(result, "Address should not be whitelisted");
    }

    function testWhitelistedMint() public {
        // Generate proof
        bytes32[] memory proof = merkle.getProof(s_leaves, 4);

        // Whitelist address attempts minting
        vm.deal(whitelist[4], 1 ether); // Fund the address
        vm.prank(whitelist[4]); // Impersonate address

        // Execute mint with correct payment
        nftContract.mint{value: 0.05 ether}(proof);

        // Assert ownership and total supply
        assertEq(nftContract.ownerOf(1), whitelist[4]);
        assertEq(nftContract.totalSupply(), 1);

        vm.prank(whitelist[4]); // Impersonate address
        vm.expectRevert("Whitelist already claimed");
        nftContract.mint{value: 0.05 ether}(proof);
    }

    function testPublicMint() public {
        // Generate proof
        bytes32[] memory proof = merkle.getProof(s_leaves, 4);
        address notWhitelisted = address(777);

        // Whitelist address attempts minting
        vm.deal(notWhitelisted, 1 ether); // Fund the address
        vm.prank(notWhitelisted); // Impersonate address

        // Execute mint with correct payment
        nftContract.mint{value: 0.1 ether}(proof);

        // Assert ownership and total supply
        assertEq(nftContract.ownerOf(1), notWhitelisted);
        assertEq(nftContract.totalSupply(), 1);
    }

    function testWhitelistedMintWithWrangValue() public {
        // Generate proof
        bytes32[] memory proof = merkle.getProof(s_leaves, 2);

        // Whitelist address attempts minting
        vm.deal(whitelist[2], 1 ether); // Fund the address
        vm.prank(whitelist[2]); // Impersonate address

        vm.expectRevert("Incorrect Ether sent");
        // Execute mint with incorrect payment
        nftContract.mint{value: 0.04 ether}(proof);

        // Assert total supply
        assertEq(nftContract.totalSupply(), 0);
    }

    function testPublicMintWithWrangValue() public {
        // Generate proof
        bytes32[] memory proof = merkle.getProof(s_leaves, 4);
        address notWhitelisted = address(777);

        // Whitelist address attempts minting
        vm.deal(notWhitelisted, 1 ether); // Fund the address
        vm.prank(notWhitelisted); // Impersonate address

        vm.expectRevert("Incorrect Ether sent");
        // Execute mint with incorrect payment
        nftContract.mint{value: 0.2 ether}(proof);

        // Assert total supply
        assertEq(nftContract.totalSupply(), 0);
    }

    function testWithdrawByOwner() public {
        // Record the initial contract balance
        uint256 initialContractBalance = address(nftContract).balance;
        uint256 initialOwnerBalance = whitelist[0].balance;

        // Ensure the owner can withdraw funds
        vm.prank(whitelist[0]); // Simulate the transaction from the owner's address
        nftContract.withdraw();

        // Check that the contract balance is now zero
        assertEq(address(nftContract).balance, 0);

        // Check that the owner's balance has increased by 10 ether
        assertEq(whitelist[0].balance, initialOwnerBalance + initialContractBalance);
    }

    function testWithdrawByNonOwner() public {
        // Ensure a non-owner cannot withdraw funds
        vm.prank(whitelist[1]); // Simulate the transaction from a non-owner's address
        vm.expectRevert();
        nftContract.withdraw();
    }

    function testSetContractURIByOwner() public {
        // Define a new contract URI
        string memory newURI = "https://new-uri.com";

        // Ensure the owner can set the contract URI
        vm.prank(whitelist[0]); // Simulate the transaction from the owner's address
        nftContract.setContractURI(newURI);

        // Verify the contract URI has been updated
        assertEq(nftContract.contractURI(), newURI);
    }

    function testSetContractURIByNonOwner() public {
        // Define a new contract URI
        string memory newURI = "https://new-uri.com";

        // Ensure a non-owner cannot set the contract URI
        vm.prank(whitelist[1]); // Simulate the transaction from a non-owner's address
        vm.expectRevert();
        nftContract.setContractURI(newURI);
    }

    function testRoyaltyInfo() public view {
        // Set a sale price for the token
        uint256 salePrice = 10 ether;

        // Check the royalty information for a given token (using tokenId 1)
        (address royaltyRecipient, uint256 royaltyAmount) = nftContract.royaltyInfo(1, salePrice);

        // Ensure the royalty recipient is the owner
        assertEq(royaltyRecipient, whitelist[0]);

        // Ensure the royalty amount is correctly calculated (5% of 10 ether)
        uint256 expectedRoyaltyAmount = (salePrice * 500) / 10000; // 5% of 1000 ether
        assertEq(royaltyAmount, expectedRoyaltyAmount);
    }

    function testSetRoyaltyInfoByOwner() public {
        // Set new royalty information
        uint96 newFee = 1000; // 10% royalty
        vm.prank(whitelist[0]); // Simulate the transaction from the owner's address
        nftContract.setRoyaltyInfo(whitelist[1], newFee);

        // Verify the new receiver and fee are correctly updated
        // Check the royalty information for a given token (using tokenId 1)
        uint256 salePrice = 10 ether;
        (address royaltyRecipient, uint256 royaltyAmount) = nftContract.royaltyInfo(1, salePrice);
        assertEq(royaltyRecipient, whitelist[1]);
        uint256 expectedRoyaltyAmount = (salePrice * 1000) / 10000; // 5% of 1000 ether
        assertEq(royaltyAmount, expectedRoyaltyAmount);
    }

    function testSetRoyaltyInfoByNonOwner() public {
        // Define a new receiver address and royalty fee
        address nonOwner = whitelist[1];
        uint96 newFee = 1000; // 10% royalty

        // Ensure that non-owner cannot call setRoyaltyInfo
        vm.prank(nonOwner); // Simulate the transaction from a non-owner's address
        vm.expectRevert();
        nftContract.setRoyaltyInfo(nonOwner, newFee);
    }

    function testOnRoyaltiesReceived() public {
        // Set up the addresses and values to be used in the test
        address royaltyRecipient = address(0x123);
        address buyer = address(0x456);
        uint256 tokenId = 1;
        address tokenPaid = address(0x789);
        uint256 amount = 1000;
        bytes32 metadata = bytes32("Royalty payment");

        // Listen for the event
        vm.expectEmit(true, true, true, true);
        emit RoyaltiesReceived(royaltyRecipient, buyer, tokenId, tokenPaid, amount, metadata);

        // Call the onRoyaltiesReceived function
        bytes4 result = nftContract.onRoyaltiesReceived(royaltyRecipient, buyer, tokenId, tokenPaid, amount, metadata);

        // Check if the return value matches the expected function selector
        bytes4 expectedSelector =
            bytes4(keccak256("onRoyaltiesReceived(address,address,uint256,address,uint256,bytes32)"));
        assertEq(result, expectedSelector, "Returned function selector should match the expected value.");
    }

    function testSupportsInterfaceForIERC2981() public view {
        // Define interface identifiers
        bytes4 INTERFACE_ID_ERC2981 = type(IERC2981).interfaceId;
        // Test if the contract supports IERC2981 interface
        bool supportsIERC2981 = nftContract.supportsInterface(INTERFACE_ID_ERC2981);
        assertTrue(supportsIERC2981, "Contract should support IERC2981 interface.");
    }

    function testTokenURI() public {
        uint256 tokenId = 1;
        // Expected token URI
        string memory expectedURI = string(abi.encodePacked(baseTokenURI, "1", baseExtension));

        bytes32[] memory proof = merkle.getProof(s_leaves, 4);
        vm.deal(whitelist[4], 1 ether);
        vm.prank(whitelist[4]);
        // Execute mint with correct payment
        nftContract.mint{value: 0.05 ether}(proof);

        // Call the tokenURI function for the tokenId
        string memory uri = nftContract.tokenURI(tokenId);

        // Assert that the returned URI matches the expected URI
        assertEq(uri, expectedURI, "The token URI should match the expected value.");
    }

    function testTokenURIForNonexistentToken() public {
        uint256 nonexistentTokenId = 999;

        // Try calling tokenURI for a nonexistent token and expect revert
        vm.expectRevert("URI query for nonexistent token");
        nftContract.tokenURI(nonexistentTokenId);
    }

    function testConstructor() public view {
        // Assert that the contract state variables are initialized correctly
        assertEq(nftContract.s_merkleRoot(), merkleRoot, "Merkle root should be set correctly");
        // assertEq(nftContract.s_royaltyFeeBasisPoints(), royaltyFeeBasisPoints, "Royalty fee should be set correctly");
        assertEq(nftContract.s_whitelistPrice(), whitelistPrice, "Whitelist price should be set correctly");
        assertEq(nftContract.s_publicPrice(), publicPrice, "Public price should be set correctly");
        assertEq(nftContract.contractURI(), contractURI, "Contract URI should be set correctly");
        // assertEq(nftContract.s_baseTokenURI(), baseTokenURI, "Base token URI should be set correctly");

        // Assert that the owner is the address that deployed the contract
        assertEq(nftContract.owner(), whitelist[0], "Owner should be the address deploying the contract");
    }
}
