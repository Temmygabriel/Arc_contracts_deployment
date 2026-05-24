// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ShoutBoard {
    struct Shout {
        address from;
        address to;
        string message;
        uint256 timestamp;
    }

    Shout[] public shouts;

    event ShoutSent(address indexed from, address indexed to, string message, uint256 id);

    function shout(address to, string calldata message) external {
        require(to != address(0), "ShoutBoard: zero address");
        require(bytes(message).length > 0, "ShoutBoard: empty message");
        require(bytes(message).length <= 200, "ShoutBoard: message too long");
        uint256 id = shouts.length;
        shouts.push(Shout(msg.sender, to, message, block.timestamp));
        emit ShoutSent(msg.sender, to, message, id);
    }

    function getShout(uint256 id) external view returns (address, address, string memory, uint256) {
        require(id < shouts.length, "ShoutBoard: invalid id");
        Shout memory s = shouts[id];
        return (s.from, s.to, s.message, s.timestamp);
    }

    function totalShouts() external view returns (uint256) {
        return shouts.length;
    }
}
