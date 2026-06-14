// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title TimeCapsule
/// @notice Seal a message on-chain. It can only be read after the unlock time passes.
/// @dev The message is stored in plaintext — for real privacy, encrypt off-chain before storing.
///      This contract enforces the *time lock*, not the privacy.
contract TimeCapsule {
    struct Capsule {
        address author;
        address recipient;
        string message;
        string label;
        uint256 sealedAt;
        uint256 unlockAt;
        bool opened;
    }

    Capsule[] public capsules;

    mapping(address => uint256[]) public capsulesBy;
    mapping(address => uint256[]) public capsulesFor;

    event CapsuleSealed(uint256 indexed id, address indexed author, address indexed recipient, uint256 unlockAt, string label);
    event CapsuleOpened(uint256 indexed id, address indexed opener);

    function seal(
        address recipient,
        string calldata message,
        string calldata label,
        uint256 unlockAt
    ) external returns (uint256) {
        require(recipient != address(0), "TimeCapsule: zero address");
        require(bytes(message).length > 0, "TimeCapsule: empty message");
        require(bytes(message).length <= 1000, "TimeCapsule: message too long");
        require(unlockAt > block.timestamp, "TimeCapsule: unlock time must be in the future");

        uint256 id = capsules.length;
        capsules.push(Capsule({
            author: msg.sender,
            recipient: recipient,
            message: message,
            label: label,
            sealedAt: block.timestamp,
            unlockAt: unlockAt,
            opened: false
        }));

        capsulesBy[msg.sender].push(id);
        capsulesFor[recipient].push(id);

        emit CapsuleSealed(id, msg.sender, recipient, unlockAt, label);
        return id;
    }

    function open(uint256 id) external returns (string memory) {
        require(id < capsules.length, "TimeCapsule: invalid id");
        Capsule storage c = capsules[id];
        require(msg.sender == c.recipient || msg.sender == c.author, "TimeCapsule: not your capsule");
        require(block.timestamp >= c.unlockAt, "TimeCapsule: not yet time");

        if (!c.opened) {
            c.opened = true;
            emit CapsuleOpened(id, msg.sender);
        }

        return c.message;
    }

    function getMeta(uint256 id) external view returns (
        address author,
        address recipient,
        string memory label,
        uint256 sealedAt,
        uint256 unlockAt,
        bool opened,
        bool unlocked
    ) {
        require(id < capsules.length, "TimeCapsule: invalid id");
        Capsule memory c = capsules[id];
        return (c.author, c.recipient, c.label, c.sealedAt, c.unlockAt, c.opened, block.timestamp >= c.unlockAt);
    }

    function capsulesSealed(address account) external view returns (uint256[] memory) {
        return capsulesBy[account];
    }

    function capsulesReceived(address account) external view returns (uint256[] memory) {
        return capsulesFor[account];
    }

    function totalCapsules() external view returns (uint256) {
        return capsules.length;
    }
}
