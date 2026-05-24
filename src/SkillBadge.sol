// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SkillBadge {
    address public owner;

    struct Badge {
        string skill;
        string level;
        uint256 awardedAt;
    }

    mapping(address => Badge[]) public badges;

    event BadgeAwarded(address indexed user, string skill, string level);
    event BadgeRevoked(address indexed user, uint256 badgeIndex);

    modifier onlyOwner() {
        require(msg.sender == owner, "SkillBadge: not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function awardBadge(address user, string calldata skill, string calldata level) external onlyOwner {
        require(user != address(0), "SkillBadge: zero address");
        require(bytes(skill).length > 0, "SkillBadge: empty skill");
        badges[user].push(Badge(skill, level, block.timestamp));
        emit BadgeAwarded(user, skill, level);
    }

    function getBadge(address user, uint256 index) external view returns (string memory, string memory, uint256) {
        require(index < badges[user].length, "SkillBadge: index out of range");
        Badge memory b = badges[user][index];
        return (b.skill, b.level, b.awardedAt);
    }

    function badgeCount(address user) external view returns (uint256) {
        return badges[user].length;
    }
}
