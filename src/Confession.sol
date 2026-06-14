// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Confession
/// @notice Post anonymous confessions on-chain. Anyone can grant absolution. No one knows who posted.
/// @dev Anonymity here is social, not cryptographic. The deployer address is visible on-chain.
///      For true anonymity, submit from a fresh wallet with no prior history.
contract Confession {
    struct ConfessionRecord {
        string text;
        string category;
        uint256 timestamp;
        uint256 absolutions;
        bool isAnonymous;
        address author;
    }

    ConfessionRecord[] public confessions;

    mapping(uint256 => mapping(address => bool)) public hasAbsolved;
    mapping(address => uint256[]) public myConfessions;

    event Confessed(uint256 indexed id, string category, bool isAnonymous, uint256 timestamp);
    event AbsolutionGranted(uint256 indexed id, address indexed absolver, uint256 totalAbsolutions);

    function confess(
        string calldata text,
        string calldata category,
        bool makeAnonymous
    ) external returns (uint256) {
        require(bytes(text).length > 0, "Confession: empty text");
        require(bytes(text).length <= 500, "Confession: too long");

        uint256 id = confessions.length;

        confessions.push(ConfessionRecord({
            text: text,
            category: category,
            timestamp: block.timestamp,
            absolutions: 0,
            isAnonymous: makeAnonymous,
            author: makeAnonymous ? address(0) : msg.sender
        }));

        if (!makeAnonymous) {
            myConfessions[msg.sender].push(id);
        }

        emit Confessed(id, category, makeAnonymous, block.timestamp);
        return id;
    }

    function absolve(uint256 id) external {
        require(id < confessions.length, "Confession: invalid id");
        require(!hasAbsolved[id][msg.sender], "Confession: already absolved");

        hasAbsolved[id][msg.sender] = true;
        confessions[id].absolutions++;

        emit AbsolutionGranted(id, msg.sender, confessions[id].absolutions);
    }

    function getConfession(uint256 id) external view returns (
        string memory text,
        string memory category,
        uint256 timestamp,
        uint256 absolutions,
        bool isAnonymous,
        address author
    ) {
        require(id < confessions.length, "Confession: invalid id");
        ConfessionRecord memory c = confessions[id];
        return (c.text, c.category, c.timestamp, c.absolutions, c.isAnonymous, c.author);
    }

    function getMyConfessions(address account) external view returns (uint256[] memory) {
        return myConfessions[account];
    }

    function totalConfessions() external view returns (uint256) {
        return confessions.length;
    }
}
