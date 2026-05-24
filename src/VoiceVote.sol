// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VoiceVote {
    struct Proposal {
        string title;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        bool closed;
        address creator;
        uint256 createdAt;
    }

    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed id, address indexed creator, string title);
    event VoteCast(uint256 indexed id, address indexed voter, bool support);
    event ProposalClosed(uint256 indexed id);

    function createProposal(string calldata title, string calldata description) external {
        require(bytes(title).length > 0, "VoiceVote: empty title");
        uint256 id = proposals.length;
        proposals.push(Proposal(title, description, 0, 0, false, msg.sender, block.timestamp));
        emit ProposalCreated(id, msg.sender, title);
    }

    function vote(uint256 id, bool support) external {
        require(id < proposals.length, "VoiceVote: invalid id");
        Proposal storage p = proposals[id];
        require(!p.closed, "VoiceVote: proposal closed");
        require(!hasVoted[id][msg.sender], "VoiceVote: already voted");
        hasVoted[id][msg.sender] = true;
        if (support) {
            p.yesVotes++;
        } else {
            p.noVotes++;
        }
        emit VoteCast(id, msg.sender, support);
    }

    function closeProposal(uint256 id) external {
        require(id < proposals.length, "VoiceVote: invalid id");
        Proposal storage p = proposals[id];
        require(msg.sender == p.creator, "VoiceVote: not creator");
        require(!p.closed, "VoiceVote: already closed");
        p.closed = true;
        emit ProposalClosed(id);
    }

    function getProposal(uint256 id) external view returns (string memory, string memory, uint256, uint256, bool) {
        require(id < proposals.length, "VoiceVote: invalid id");
        Proposal memory p = proposals[id];
        return (p.title, p.description, p.yesVotes, p.noVotes, p.closed);
    }

    function totalProposals() external view returns (uint256) {
        return proposals.length;
    }
}
