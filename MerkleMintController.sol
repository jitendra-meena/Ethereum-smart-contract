//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "./merkleProof/Verify.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./IMerkleMintCore.sol";

/**
 * @title MerkleMintController Controller for MerkleProof based Token Minting
 * @dev The ERC721 token is deployed seperately, with MerkleMintController set as an allowed Minter.
 * @dev To mint a token a merkle proof is required. MerkleProofs belong to inidivial Serie with are part of Series.
 * @dev This ensure that each series is limited in quantity, but additional series can be added as required.
 * @dev It is intended that the owner is set as a MultiSig or DAO contract, and the owner can add new series with MerkleRoots.
 * @dev This allows for manageing a token that can assure users that assets belong to a set of defined range.
 */
contract MerkleMintController is Verify, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _series;

    // Creator Role
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");


    // Address of the NFT Token
    IMerkleMintCore public token;

    // Definition of a Series
    struct Serie {
        bytes32 merkleRoot; // Merkle Root
        bytes32[] ipfsHash; // Series Metadata
        string serieName; // Name
        uint256 seriesID; // Series ID
        uint256 totalTokens; // Total items in series
        uint256 itemsRedeemed; //The number of tokens that have been minted so far in this series
        uint256[] catalogue; //Each token currently minted in the series
    }

    // Maping of Series by integer
    mapping(uint256 => Serie) public archive;

    // Mapping associating a token Id to a series
    mapping(uint256 => uint256) public tokenInSeriesRegister;

    // Minted Assets
    mapping(bytes32 => bool) public hasAssetBeenMinted;

    // Series Added Event
    event SerieAdded(
        uint256 indexed SeriesNumber,
        bytes32 IPFSHash,
        bytes32 indexed MerkleRoot,
        string SerieName
    );

    // Metadata added to a series
    event MetadataAdded(uint256 indexed SeriesNumber, bytes32 IPFSHash);

    // MerkleMint
    event MerkleMinted(address Caller, address Recipient, string TokenURI, uint256 Series, bytes32 root, bytes32 leaf, uint256 seriesIndex);

    /**
     * @dev Initialized the Controller Contract. Called at deployment time.
     * @param _token is the address of the IMerkleMintCore contract.
     * @param creators is the address of the people who can create series.
     */
    constructor(IMerkleMintCore _token, address[] memory creators, address[] memory minters) {

        // TODO: Set the Role Admins

        // Setup Creators
        for (uint256 x; x < creators.length; x++) {
            _setupRole(CREATOR_ROLE, creators[x]);

        }

        // Setup Minters
        for (uint256 x; x < minters.length; x++) {
            _setupRole(MINTER_ROLE, minters[x]);

        }

        // Setup Token
        token = _token;
    }

    /**
     * @dev Add a new merkle Root to a serie.
     * @param merkleRoot is the merkle root for the serie.
     * @param name is the name of the serie.
     * @param ipfsHash is the first off-chain data location for the serie. (More can be added seperately)
     */
    function addSerie(
        bytes32 merkleRoot,
        string memory name,
        bytes32 ipfsHash,
        uint256 itemCount
    ) external {
        // Require that this is a valid Series
        require(merkleRoot.length > 0, "No Merkle Root provided");
        require(bytes(name).length > 0, "No Name provided");
        require(ipfsHash.length > 0, "No IPFS hash provided");
        require(itemCount > 0, "Invalid Item Count");

        // Caller must have the Creator role
        require(hasRole(CREATOR_ROLE, msg.sender), "Caller is not a creator");

        // Get new series number
        uint256 seriesNumber = _series.current();

        // Add info to Series mapping
        archive[seriesNumber].merkleRoot = merkleRoot;
        archive[seriesNumber].seriesID = seriesNumber;
        archive[seriesNumber].serieName = name;
        archive[seriesNumber].totalTokens = itemCount;
        archive[seriesNumber].itemsRedeemed = 0;
        archive[seriesNumber].ipfsHash.push(ipfsHash);

        // Increment Series count
        _series.increment();

        emit SerieAdded(seriesNumber, ipfsHash, merkleRoot, name);
    }

    // Getters
    function getCatalogueSize(uint256 series) public view returns (uint256){
        return archive[series].catalogue.length;
    }

    /**
     * @dev Mint a new Asset (ERC721 Token)
     * @param recipient the recipient of the token
     * @param tokenURI URI for the token.
     * @param leaf required for the merkleproof.
     * @param proof provided for verification.
     * @param series that the merkleproof should check against.
     */
    function mintAsset(
        address recipient,
        string memory tokenURI,
        bytes32 leaf,
        bytes32[] memory proof,
        uint256 series
    ) external {

        // Require that Series Exists
        require(archive[series].merkleRoot.length > 0, "Series does not exist");
        
        // Asset Hash
        bytes32 assetHash = keccak256(abi.encodePacked(tokenURI, series, leaf, proof));

        // Require this tokenURI has not been minted previously
        require(!hasAssetBeenMinted[assetHash], "Asset has already been minted");

        // Require that the merkle data is correct
        require(
            isValidData(tokenURI, _findRoot(series), leaf, proof),
            "MerkleMintController:: Not a valid Asset"
        );

        // Mint the token
        uint256 tokenId = token.merkleMint(recipient, tokenURI);

        // Record the Token minted in the series
        archive[series].catalogue.push(tokenId);

        // Increment the number of tokens minted so far
        archive[series].itemsRedeemed++;

        // Mark asset as minted
        hasAssetBeenMinted[assetHash] = true;

        // Emit MerkleMinted
        emit MerkleMinted(msg.sender, recipient, tokenURI, series, _findRoot(series), leaf, archive[series].catalogue.length-1);
    }
    

    /**
     * @dev Function to add a new IPFS reference to a Serie
     * @param _ipfsHash of the off-chain reference to add to the serie.
     * @param seriesNumber of the Serie the hash should be added to.
     */
    function addIpfsRefToSerie(bytes32 _ipfsHash, uint256 seriesNumber)
        external
    {
        require(hasRole(CREATOR_ROLE, msg.sender), "Caller is not a creator");

        require(
            archive[seriesNumber].seriesID == seriesNumber,
            "MerkleMintController::addIpfsRefToSerie:: Serie does not Exist"
        );

        archive[seriesNumber].ipfsHash.push(_ipfsHash);
        emit MetadataAdded(seriesNumber, _ipfsHash);
    }

    // Internal function to find the root which accompanies the requested serie.

    function _findRoot(uint256 _serie) internal view returns (bytes32) {
        bytes32 merkleRoot = archive[_serie].merkleRoot;
        require(
            merkleRoot != bytes32(0),
            "MerkleMintController::_findRoot:: No such series exists"
        );
        return merkleRoot;
    }
}
