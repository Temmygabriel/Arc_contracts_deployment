// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract QuestBoard {
    struct Quest {
        address poster;
        string title;
        string description;
        string reward;
        bool completed;
        address completedBy;
        uint256 createdAt;
    }

    Quest[] public quests;

    event QuestPosted(uint256 indexed id, address indexed poster, string title);
    event QuestCompleted(uint256 indexed id, address indexed completedBy);

    function postQuest(string calldata title, string calldata description, string calldata reward) external {
        require(bytes(title).length > 0, "QuestBoard: empty title");
        require(bytes(description).length > 0, "QuestBoard: empty description");
        uint256 id = quests.length;
        quests.push(Quest(msg.sender, title, description, reward, false, address(0), block.timestamp));
        emit QuestPosted(id, msg.sender, title);
    }

    function completeQuest(uint256 id, address completedBy) external {
        require(id < quests.length, "QuestBoard: invalid id");
        Quest storage q = quests[id];
        require(msg.sender == q.poster, "QuestBoard: not poster");
        require(!q.completed, "QuestBoard: already completed");
        require(completedBy != address(0), "QuestBoard: zero address");
        q.completed = true;
        q.completedBy = completedBy;
        emit QuestCompleted(id, completedBy);
    }

    function getQuest(uint256 id) external view returns (address, string memory, string memory, string memory, bool, address) {
        require(id < quests.length, "QuestBoard: invalid id");
        Quest memory q = quests[id];
        return (q.poster, q.title, q.description, q.reward, q.completed, q.completedBy);
    }

    function totalQuests() external view returns (uint256) {
        return quests.length;
    }
}
