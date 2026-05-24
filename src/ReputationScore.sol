// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ReputationScore {
    address public owner;
    mapping(address => uint256) public scores;
    mapping(address => string[]) public reasons;

    event ScoreAwarded(address indexed user, uint256 amount, string reason);
    event ScoreDeducted(address indexed user, uint256 amount, string reason);

    modifier onlyOwner() {
        require(msg.sender == owner, "ReputationScore: not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function award(address user, uint256 amount, string calldata reason) external onlyOwner {
        require(user != address(0), "ReputationScore: zero address");
        require(amount > 0, "ReputationScore: zero amount");
        scores[user] += amount;
        reasons[user].push(reason);
        emit ScoreAwarded(user, amount, reason);
    }

    function deduct(address user, uint256 amount, string calldata reason) external onlyOwner {
        require(scores[user] >= amount, "ReputationScore: insufficient score");
        scores[user] -= amount;
        emit ScoreDeducted(user, amount, reason);
    }

    function getScore(address user) external view returns (uint256) {
        return scores[user];
    }

    function getReasonsCount(address user) external view returns (uint256) {
        return reasons[user].length;
    }
}
