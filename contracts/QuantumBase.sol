// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title QuantumBase
 * @dev Generic registry for hashed quantum-safe artifacts and their metadata
 * @notice Stores versioned records keyed by logical resource IDs
 */
contract QuantumBase {
    // Basic access control
    address public owner;

    // Logical resource identifier => current active version
    mapping(bytes32 => uint256) public currentVersion;

    struct QuantumRecord {
        bytes32 resourceId;      // logical id for a family of records
        uint256 version;         // monotonically increasing version
        bytes32 payloadHash;     // hash of the off-chain artifact / payload
        string  algorithm;       // e.g. "KYBER1024", "DILITHIUM5"
        string  uri;             // reference to off-chain data (IPFS, HTTPS, etc.)
        uint256 createdAt;       // timestamp when stored
        bool    isActive;        // soft-delete flag
    }

    // recordId => QuantumRecord
    mapping(bytes32 => QuantumRecord) public records;

    // resourceId => list of recordIds (all historical versions)
    mapping(bytes32 => bytes32[]) public versionsOf;

    event RecordStored(
        bytes32 indexed recordId,
        bytes32 indexed resourceId,
        uint256 indexed version,
        bytes32 payloadHash,
        string algorithm,
        string uri,
        uint256 createdAt
    );

    event RecordDeactivated(
        bytes32 indexed recordId,
        bytes32 indexed resourceId,
        uint256 timestamp
    );

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier recordExists(bytes32 recordId) {
        require(records[recordId].createdAt != 0, "Record not found");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Store a new quantum-safe artifact record
     * @param resourceId Logical identifier of the resource this record belongs to
     * @param payloadHash Hash of the quantum-safe artifact / key / proof
     * @param algorithm Name of the algorithm family
     * @param uri Off-chain reference for full data
     * @return recordId Deterministic identifier of the stored record
     */
    function storeRecord(
        bytes32 resourceId,
        bytes32 payloadHash,
        string calldata algorithm,
        string calldata uri
    ) external onlyOwner returns (bytes32 recordId) {
        require(resourceId != 0, "Invalid resourceId");
        require(payloadHash != 0, "Invalid payload hash");

        uint256 nextVersion = currentVersion[resourceId] + 1;
        currentVersion[resourceId] = nextVersion;

        recordId = keccak256(abi.encodePacked(resourceId, nextVersion, payloadHash));

        QuantumRecord storage rec = records[recordId];
        require(rec.createdAt == 0, "Record already exists");

        rec.resourceId = resourceId;
        rec.version = nextVersion;
        rec.payloadHash = payloadHash;
        rec.algorithm = algorithm;
        rec.uri = uri;
        rec.createdAt = block.timestamp;
        rec.isActive = true;

        versionsOf[resourceId].push(recordId);

        emit RecordStored(
            recordId,
            resourceId,
            nextVersion,
            payloadHash,
            algorithm,
            uri,
            block.timestamp
        );
    }

    /**
     * @dev Deactivate a record (soft delete)
     * @param recordId Identifier of the record
     */
    function deactivateRecord(bytes32 recordId)
        external
        onlyOwner
        recordExists(recordId)
    {
        QuantumRecord storage rec = records[recordId];
        require(rec.isActive, "Already inactive");

        rec.isActive = false;

        emit RecordDeactivated(recordId, rec.resourceId, block.timestamp);
    }

    /**
     * @dev Get latest active record for a given resourceId
     * @param resourceId Logical resource identifier
     */
    function getLatestRecord(bytes32 resourceId)
        external
        view
        returns (
            bytes32 recordId,
            bytes32 _resourceId,
            uint256 version,
            bytes32 payloadHash,
            string memory algorithm,
            string memory uri,
            uint256 createdAt,
            bool isActive
        )
    {
        uint256 v = currentVersion[resourceId];
        require(v > 0, "No versions");

        bytes32[] storage list = versionsOf[resourceId];
        // latest should be last pushed
        recordId = list[list.length - 1];

        QuantumRecord memory rec = records[recordId];
        return (
            recordId,
            rec.resourceId,
            rec.version,
            rec.payloadHash,
            rec.algorithm,
            rec.uri,
            rec.createdAt,
            rec.isActive
        );
    }

    /**
     * @dev Get all recordIds (all versions) for a resourceId
     * @param resourceId Logical resource identifier
     */
    function getVersionsOf(bytes32 resourceId)
        external
        view
        returns (bytes32[] memory)
    {
        return versionsOf[resourceId];
    }

    /**
     * @dev Read a specific record by id
     * @param recordId Identifier of the record
     */
    function getRecord(bytes32 recordId)
        external
        view
        recordExists(recordId)
        returns (
            bytes32 resourceId,
            uint256 version,
            bytes32 payloadHash,
            string memory algorithm,
            string memory uri,
            uint256 createdAt,
            bool isActive
        )
    {
        QuantumRecord memory rec = records[recordId];
        return (
            rec.resourceId,
            rec.version,
            rec.payloadHash,
            rec.algorithm,
            rec.uri,
            rec.createdAt,
            rec.isActive
        );
    }

    /**
     * @dev Transfer contract ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }
}
