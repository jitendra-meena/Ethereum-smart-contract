//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Complete ERC721 Non-Fungible Token Standard basic implementation with Metadata, Minting, and Pause Functionality
 * @dev see https://eips.ethereum.org/EIPS/eip-721
 * @dev Based on OpenZeppelin Contracts Ethereum Package
 * @dev see https://github.com/OpenZeppelin/openzeppelin-contracts-ethereum-package
 */
contract MerkleMintCore is ERC721, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /**
     * @dev Initialize the Token Contract with Minters and Pausers. The name+symbol are hardCoded.
     * @param TokenName the name of the contract.
     * @param TokenSymbol the symbol of the contract.
     * @param admins array of addresses that are allowed to mint.
     */
    constructor(
        string memory TokenName,
        string memory TokenSymbol,
        address[] memory admins
    ) ERC721(TokenName, TokenSymbol) {
        // Setup Roles
        for (uint256 x; x < admins.length; x++) {
            _setupRole(MINTER_ROLE, admins[x]);
            _setupRole(BURNER_ROLE, admins[x]);
        }
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address recipient, string memory tokenURI)
        public
        returns (uint256)
    {
        // Caller must have minter role
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");

        // Get new TokenId
        uint256 newItemId = _tokenIds.current();

        // Mint and set TokenID
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        // Increment at the end so it starts at zero
        _tokenIds.increment();

        // Return id
        return newItemId;
    }

    function merkleMint(address recipient, string memory tokenURI)
        public
        returns (uint256)
    {
        // Caller must have minter role
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");

        // Get new TokenId
        uint256 newItemId = _tokenIds.current();

        // Mint and set TokenID
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        // Increment at the end so it starts at zero
        _tokenIds.increment();

        // Return id
        return newItemId;
    }
}
