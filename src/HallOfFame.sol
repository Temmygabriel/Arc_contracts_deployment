// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HallOfFame {
    address public owner;

    struct Nominee {
        address account;
        string name;
        string reason;
        uint256 nominatedAt;
    }

    Nominee[] public nominees;
    mapping(address => bool) public isNominated;

    event Nominated(uint256 indexed id, address indexed account, string name, string reason);

    modifier onlyOwner() {
        require(msg.sender == owner, "HallOfFame: not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function nominate(address account, string calldata name, string calldata reason) external onlyOwner {
        require(account != address(0), "HallOfFame: zero address");
        require(!isNominated[account], "HallOfFame: already nominated");
        require(bytes(name).length > 0, "HallOfFame: empty name");
        require(bytes(reason).length > 0, "HallOfFame: empty reason");
        uint256 id = nominees.length;
        nominees.push(Nominee(account, name, reason, block.timestamp));
        isNominated[account] = true;
        emit Nominated(id, account, name, reason);
    }

    function getNominee(uint256 id) external view returns (address, string memory, string memory, uint256) {
        require(id < nominees.length, "HallOfFame: invalid id");
        Nominee memory n = nominees[id];
        return (n.account, n.name, n.reason, n.nominatedAt);
    }

    function totalNominees() external view returns (uint256) {
        return nominees.length;
    }
}
