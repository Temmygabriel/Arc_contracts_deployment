// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Pact
/// @notice Two people make a mutual commitment. Both must sign. Either can break it — but breaking is permanent and public.
contract Pact {
    enum Status { Proposed, Active, Broken, Completed }

    struct PactRecord {
        address proposer;
        address counterpart;
        string terms;
        uint256 proposedAt;
        uint256 activatedAt;
        Status status;
        address brokenBy;
        string breakReason;
    }

    PactRecord[] public pacts;

    mapping(address => uint256[]) public pactsByAddress;

    event PactProposed(uint256 indexed id, address indexed proposer, address indexed counterpart, string terms);
    event PactActivated(uint256 indexed id, address indexed counterpart);
    event PactBroken(uint256 indexed id, address indexed breakerAddress, string reason);
    event PactCompleted(uint256 indexed id);

    function propose(address counterpart, string calldata terms) external returns (uint256) {
        require(counterpart != address(0), "Pact: zero address");
        require(counterpart != msg.sender, "Pact: cannot pact with yourself");
        require(bytes(terms).length > 0, "Pact: empty terms");
        require(bytes(terms).length <= 500, "Pact: terms too long");

        uint256 id = pacts.length;
        pacts.push(PactRecord({
            proposer: msg.sender,
            counterpart: counterpart,
            terms: terms,
            proposedAt: block.timestamp,
            activatedAt: 0,
            status: Status.Proposed,
            brokenBy: address(0),
            breakReason: ""
        }));

        pactsByAddress[msg.sender].push(id);
        pactsByAddress[counterpart].push(id);

        emit PactProposed(id, msg.sender, counterpart, terms);
        return id;
    }

    function accept(uint256 id) external {
        require(id < pacts.length, "Pact: invalid id");
        PactRecord storage p = pacts[id];
        require(msg.sender == p.counterpart, "Pact: not the counterpart");
        require(p.status == Status.Proposed, "Pact: not in proposed state");

        p.status = Status.Active;
        p.activatedAt = block.timestamp;

        emit PactActivated(id, msg.sender);
    }

    function breakPact(uint256 id, string calldata reason) external {
        require(id < pacts.length, "Pact: invalid id");
        PactRecord storage p = pacts[id];
        require(msg.sender == p.proposer || msg.sender == p.counterpart, "Pact: not a participant");
        require(p.status == Status.Active, "Pact: pact is not active");

        p.status = Status.Broken;
        p.brokenBy = msg.sender;
        p.breakReason = reason;

        emit PactBroken(id, msg.sender, reason);
    }

    function complete(uint256 id) external {
        require(id < pacts.length, "Pact: invalid id");
        PactRecord storage p = pacts[id];
        require(msg.sender == p.proposer || msg.sender == p.counterpart, "Pact: not a participant");
        require(p.status == Status.Active, "Pact: pact is not active");

        p.status = Status.Completed;

        emit PactCompleted(id);
    }

    function getPact(uint256 id) external view returns (
        address proposer,
        address counterpart,
        string memory terms,
        uint256 proposedAt,
        uint256 activatedAt,
        Status status,
        address brokenBy,
        string memory breakReason
    ) {
        require(id < pacts.length, "Pact: invalid id");
        PactRecord memory p = pacts[id];
        return (p.proposer, p.counterpart, p.terms, p.proposedAt, p.activatedAt, p.status, p.brokenBy, p.breakReason);
    }

    function getPactsByAddress(address account) external view returns (uint256[] memory) {
        return pactsByAddress[account];
    }

    function totalPacts() external view returns (uint256) {
        return pacts.length;
    }
}
