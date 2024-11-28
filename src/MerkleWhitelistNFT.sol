// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract MerkleWhitelistNFT is ERC721Enumerable, Ownable, IERC2981 {
    using Strings for uint256;

    // Merkle Root for whitelist verification
    bytes32 public s_merkleRoot;

    // Tracking whitelist claims
    mapping(address => bool) public s_whitelistClaimed;

    // Royalty parameters
    address private s_royaltyReceiver;
    uint96 private s_royaltyFeeBasisPoints;

    // Mint prices
    uint256 public s_whitelistPrice;
    uint256 public s_publicPrice;

    // Metadata URIs
    string private s_contractURI;
    string private s_baseTokenURI;
    string public s_baseExtension = ".json";

    /**
     * @notice Event emitted when royalties are received.
     * @param royaltyRecipient The address receiving the royalty.
     * @param buyer The address that paid for the token.
     * @param tokenId The ID of the token involved in the royalty.
     * @param tokenPaid The token used for the payment (e.g., ETH, USDC).
     * @param amount The amount of the royalty paid.
     * @param metadata Additional metadata (if any) about the payment.
     */
    event RoyaltiesReceived(
        address indexed royaltyRecipient,
        address indexed buyer,
        uint256 indexed tokenId,
        address tokenPaid,
        uint256 amount,
        bytes32 metadata
    );

    /**
     * @notice Initializes the contract with Merkle Root, royalty info, mint prices, and URIs.
     * @param merkleRoot The root of the Merkle Tree for whitelist validation.
     * @param royaltyFeeBasisPoints The royalty fee in basis points (1% = 100).
     * @param whitelistPrice Price for whitelist minting.
     * @param publicPrice Price for public minting.
     * @param initialContractURI Metadata URI for the contract.
     * @param baseTokenURI Base URI for token metadata.
     */
    constructor(
        bytes32 merkleRoot,
        uint96 royaltyFeeBasisPoints,
        uint256 whitelistPrice,
        uint256 publicPrice,
        string memory initialContractURI,
        string memory baseTokenURI
    ) ERC721("MerkleWhitelistNFT", "MWNFT") Ownable(msg.sender) {
        s_merkleRoot = merkleRoot;
        s_royaltyReceiver = msg.sender; // Set msg.sender as the initial royalty receiver
        s_royaltyFeeBasisPoints = royaltyFeeBasisPoints;
        s_whitelistPrice = whitelistPrice;
        s_publicPrice = publicPrice;
        s_contractURI = initialContractURI;
        s_baseTokenURI = baseTokenURI;
    }

    /**
     * @notice Mints an NFT for the sender. Checks whitelist proof and price.
     * @param merkleProof The Merkle proof for whitelist verification.
     * @dev Whitelist users pay `s_whitelistPrice`, others pay `s_publicPrice`.
     */
    function mint(bytes32[] calldata merkleProof) external payable {
        uint256 price;

        if (isWhitelisted(msg.sender, merkleProof)) {
            require(!s_whitelistClaimed[msg.sender], "Whitelist already claimed");
            s_whitelistClaimed[msg.sender] = true;
            price = s_whitelistPrice;
        } else {
            price = s_publicPrice;
        }

        require(msg.value == price, "Incorrect Ether sent");

        uint256 tokenId = totalSupply() + 1;
        _safeMint(msg.sender, tokenId);
    }

    /**
     * @notice Checks if an address is whitelisted using Merkle proof.
     * @param account The address to check.
     * @param proof The Merkle proof provided by the user.
     * @return bool True if the address is whitelisted, false otherwise.
     */
    function isWhitelisted(address account, bytes32[] calldata proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(proof, s_merkleRoot, leaf);
    }

    /**
     * @notice Withdraws all Ether from the contract to the owner's address.
     * @dev Only callable by the owner.
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @notice Returns the URI containing metadata for the contract.
     * @return string The contract-level metadata URI.
     */
    function contractURI() public view returns (string memory) {
        return s_contractURI;
    }

    /**
     * @notice Sets a new URI for the contract metadata.
     * @param newContractURI The new contract metadata URI.
     * @dev Only callable by the owner.
     */
    function setContractURI(string calldata newContractURI) external onlyOwner {
        s_contractURI = newContractURI;
    }

    /**
     * @notice Returns the token metadata URI for a given token ID.
     * @param tokenId The ID of the token to query.
     * @return string The full metadata URI for the token.
     * @dev Throws if the token does not exist.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_ownerOf(tokenId) != address(0), "URI query for nonexistent token");

        string memory currentBaseURI = s_baseTokenURI;
        return
            bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), s_baseExtension))
                : "";
    }

    /**
     * @notice Returns royalty information for a token sale.
     * @notice param _tokenId The ID of the token (not used but required by interface).
     * @param _salePrice The sale price of the token.
     * @return receiver The address receiving royalties.
     * @return royaltyAmount The amount of royalties to be paid.
     */
    function royaltyInfo(uint256 /*_tokenId*/, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = s_royaltyReceiver;
        royaltyAmount = (_salePrice * s_royaltyFeeBasisPoints) / 10000;
    }

    /**
     * @notice Sets new royalty information.
     * @param receiver The new royalty receiver.
     * @param feeBasisPoints The new royalty fee in basis points.
     * @dev Only callable by the owner.
     */
    function setRoyaltyInfo(address receiver, uint96 feeBasisPoints) external onlyOwner {
        s_royaltyReceiver = receiver;
        s_royaltyFeeBasisPoints = feeBasisPoints;
    }

    /**
     * @notice Handles royalty receipt events.
     * @param _royaltyRecipient The address receiving the royalty.
     * @param _buyer The address paying for the royalty.
     * @param _tokenId The token ID for which the royalty is paid.
     * @param _tokenPaid The token used for payment (e.g., ETH, USDC).
     * @param _amount The amount paid as royalty.
     * @param _metadata Optional metadata about the payment.
     * @return bytes4 A selector confirming the function was called successfully.
     */
    function onRoyaltiesReceived(
        address _royaltyRecipient,
        address _buyer,
        uint256 _tokenId,
        address _tokenPaid,
        uint256 _amount,
        bytes32 _metadata
    ) external returns (bytes4) {
        emit RoyaltiesReceived(_royaltyRecipient, _buyer, _tokenId, _tokenPaid, _amount, _metadata);
        return
            bytes4(
                keccak256(
                    "onRoyaltiesReceived(address,address,uint256,address,uint256,bytes32)"
                )
            );
    }

    /**
     * @notice Indicates support for interfaces.
     * @param interfaceId The interface identifier.
     * @return bool True if the interface is supported, false otherwise.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}
