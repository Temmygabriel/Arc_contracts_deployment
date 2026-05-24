// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract IdentityCard {
    struct Profile {
        string name;
        string bio;
        string avatarUrl;
        uint256 createdAt;
        bool exists;
    }

    mapping(address => Profile) public profiles;

    event ProfileCreated(address indexed user, string name);
    event ProfileUpdated(address indexed user);

    function createProfile(string calldata name, string calldata bio, string calldata avatarUrl) external {
        require(!profiles[msg.sender].exists, "IdentityCard: profile already exists");
        require(bytes(name).length > 0, "IdentityCard: name required");
        profiles[msg.sender] = Profile(name, bio, avatarUrl, block.timestamp, true);
        emit ProfileCreated(msg.sender, name);
    }

    function updateProfile(string calldata bio, string calldata avatarUrl) external {
        require(profiles[msg.sender].exists, "IdentityCard: no profile found");
        profiles[msg.sender].bio = bio;
        profiles[msg.sender].avatarUrl = avatarUrl;
        emit ProfileUpdated(msg.sender);
    }

    function getProfile(address user) external view returns (string memory, string memory, string memory, uint256) {
        Profile memory p = profiles[user];
        require(p.exists, "IdentityCard: no profile found");
        return (p.name, p.bio, p.avatarUrl, p.createdAt);
    }

    function hasProfile(address user) external view returns (bool) {
        return profiles[user].exists;
    }
}
