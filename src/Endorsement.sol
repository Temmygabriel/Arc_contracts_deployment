// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Endorsement
/// @notice Endorse someone's skill on-chain. Unlike badges (which are owner-issued),
///         endorsements come from peers. Anyone can endorse anyone — but only once per skill.
///         The weight of an endorsement lives in who gave it, not the contract.
contract Endorsement {
    struct EndorsementRecord {
        address endorser;
        address recipient;
        string skill;
        string comment;
        uint256 givenAt;
    }

    EndorsementRecord[] public endorsements;

    /// @dev endorser => recipient => skill => whether endorsed
    mapping(address => mapping(address => mapping(string => bool))) public hasEndorsed;

    /// @dev recipient => list of endorsement ids
    mapping(address => uint256[]) public endorsementsReceived;

    /// @dev endorser => list of endorsement ids
    mapping(address => uint256[]) public endorsementsGiven;

    /// @dev recipient => skill => count
    mapping(address => mapping(string => uint256)) public skillEndorsementCount;

    event Endorsed(
        uint256 indexed id,
        address indexed endorser,
        address indexed recipient,
        string skill,
        string comment
    );

    event EndorsementRevoked(uint256 indexed id, address indexed endorser);

    function endorse(
        address recipient,
        string calldata skill,
        string calldata comment
    ) external returns (uint256) {
        require(recipient != address(0), "Endorsement: zero address");
        require(recipient != msg.sender, "Endorsement: cannot endorse yourself");
        require(bytes(skill).length > 0, "Endorsement: empty skill");
        require(bytes(skill).length <= 60, "Endorsement: skill too long");
        require(bytes(comment).length <= 280, "Endorsement: comment too long");
        require(!hasEndorsed[msg.sender][recipient][skill], "Endorsement: already endorsed this skill");

        uint256 id = endorsements.length;

        endorsements.push(EndorsementRecord({
            endorser: msg.sender,
            recipient: recipient,
            skill: skill,
            comment: comment,
            givenAt: block.timestamp
        }));

        hasEndorsed[msg.sender][recipient][skill] = true;
        endorsementsReceived[recipient].push(id);
        endorsementsGiven[msg.sender].push(id);
        skillEndorsementCount[recipient][skill]++;

        emit Endorsed(id, msg.sender, recipient, skill, comment);
        return id;
    }

    function getEndorsement(uint256 id) external view returns (
        address endorser,
        address recipient,
        string memory skill,
        string memory comment,
        uint256 givenAt
    ) {
        require(id < endorsements.length, "Endorsement: invalid id");
        EndorsementRecord memory e = endorsements[id];
        return (e.endorser, e.recipient, e.skill, e.comment, e.givenAt);
    }

    function getEndorsementsReceived(address account) external view returns (uint256[] memory) {
        return endorsementsReceived[account];
    }

    function getEndorsementsGiven(address account) external view returns (uint256[] memory) {
        return endorsementsGiven[account];
    }

    function getSkillCount(address account, string calldata skill) external view returns (uint256) {
        return skillEndorsementCount[account][skill];
    }

    function totalEndorsements() external view returns (uint256) {
        return endorsements.length;
    }
}
