// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MoodRing {
    struct Mood {
        string emoji;
        string note;
        uint256 setAt;
    }

    mapping(address => Mood) public moods;

    event MoodSet(address indexed user, string emoji, string note);

    function setMood(string calldata emoji, string calldata note) external {
        require(bytes(emoji).length > 0, "MoodRing: empty emoji");
        require(bytes(emoji).length <= 16, "MoodRing: emoji too long");
        require(bytes(note).length <= 100, "MoodRing: note too long");
        moods[msg.sender] = Mood(emoji, note, block.timestamp);
        emit MoodSet(msg.sender, emoji, note);
    }

    function getMood(address user) external view returns (string memory, string memory, uint256) {
        Mood memory m = moods[user];
        return (m.emoji, m.note, m.setAt);
    }

    function hasMood(address user) external view returns (bool) {
        return moods[user].setAt > 0;
    }
}
