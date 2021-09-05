//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IMerkleMintCore is IERC721 {
    function mint(address recipient, string memory tokenURI)
        external
        returns (uint256);

    function merkleMint(address recipient, string memory tokenURI)
        external
        returns (uint256);
}
