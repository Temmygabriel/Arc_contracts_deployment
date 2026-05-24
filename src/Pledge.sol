// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Pledge {
    struct PledgeRecord {
        address pledger;
        string commitment;
        uint256 deadline;
        bool fulfilled;
        uint256 createdAt;
    }

    PledgeRecord[] public pledges;

    event PledgeMade(uint256 indexed id, address indexed pledger, string commitment, uint256 deadline);
    event PledgeFulfilled(uint256 indexed id, address indexed pledger);

    function makePledge(string calldata commitment, uint256 deadlineTimestamp) external {
        require(bytes(commitment).length > 0, "Pledge: empty commitment");
        require(bytes(commitment).length <= 280, "Pledge: commitment too long");
        require(deadlineTimestamp > block.timestamp, "Pledge: deadline in the past");
        uint256 id = pledges.length;
        pledges.push(PledgeRecord(msg.sender, commitment, deadlineTimestamp, false, block.timestamp));
        emit PledgeMade(id, msg.sender, commitment, deadlineTimestamp);
    }

    function fulfillPledge(uint256 id) external {
        require(id < pledges.length, "Pledge: invalid id");
        PledgeRecord storage p = pledges[id];
        require(msg.sender == p.pledger, "Pledge: not pledger");
        require(!p.fulfilled, "Pledge: already fulfilled");
        p.fulfilled = true;
        emit PledgeFulfilled(id, msg.sender);
    }

    function getPledge(uint256 id) external view returns (address, string memory, uint256, bool, uint256) {
        require(id < pledges.length, "Pledge: invalid id");
        PledgeRecord memory p = pledges[id];
        return (p.pledger, p.commitment, p.deadline, p.fulfilled, p.createdAt);
    }

    function totalPledges() external view returns (uint256) {
        return pledges.length;
    }
}
