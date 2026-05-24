// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TrustCircle {
    mapping(address => mapping(address => bool)) public trusts;
    mapping(address => uint256) public trustCount;
    mapping(address => address[]) public trustedBy;

    event TrustAdded(address indexed from, address indexed to);
    event TrustRemoved(address indexed from, address indexed to);

    function addTrust(address account) external {
        require(account != address(0), "TrustCircle: zero address");
        require(account != msg.sender, "TrustCircle: cannot trust yourself");
        require(!trusts[msg.sender][account], "TrustCircle: already trusted");
        trusts[msg.sender][account] = true;
        trustCount[account]++;
        trustedBy[account].push(msg.sender);
        emit TrustAdded(msg.sender, account);
    }

    function removeTrust(address account) external {
        require(trusts[msg.sender][account], "TrustCircle: not trusted");
        trusts[msg.sender][account] = false;
        trustCount[account]--;
        emit TrustRemoved(msg.sender, account);
    }

    function isTrusted(address from, address to) external view returns (bool) {
        return trusts[from][to];
    }

    function getTrustCount(address account) external view returns (uint256) {
        return trustCount[account];
    }
}
