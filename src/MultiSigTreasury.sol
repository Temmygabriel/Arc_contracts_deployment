// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MultiSigTreasury
/// @notice An N-of-M multisig treasury. Any signer proposes a native USDC payout
///         with a recipient and memo. It requires threshold approvals from other signers
///         before execution. Any signer can also veto before the threshold is met.
contract MultiSigTreasury {
    struct Treasury {
        address[] signers;
        uint256 threshold;
        uint256 balance;
        string name;
        uint256 createdAt;
    }

    struct Proposal {
        uint256 treasuryId;
        address proposer;
        address recipient;
        uint256 amount;
        string memo;
        uint256 approvals;
        bool executed;
        bool vetoed;
        uint256 createdAt;
    }

    Treasury[] public treasuries;
    Proposal[] public proposals;

    mapping(uint256 => mapping(address => bool)) public isSigner;
    mapping(uint256 => mapping(address => bool)) public hasApproved;
    mapping(uint256 => uint256[]) public proposalsByTreasury;
    mapping(address => uint256[]) public treasuriesBySigner;

    event TreasuryCreated(uint256 indexed id, string name, address[] signers, uint256 threshold);
    event Deposited(uint256 indexed treasuryId, address indexed from, uint256 amount);
    event ProposalCreated(uint256 indexed id, uint256 indexed treasuryId, address indexed recipient, uint256 amount, string memo);
    event ProposalApproved(uint256 indexed id, address indexed signer, uint256 approvals);
    event ProposalExecuted(uint256 indexed id, address indexed recipient, uint256 amount);
    event ProposalVetoed(uint256 indexed id, address indexed signer);

    function createTreasury(string calldata name, address[] calldata signers, uint256 threshold) external returns (uint256) {
        require(bytes(name).length > 0, "MultiSigTreasury: empty name");
        require(signers.length >= 2, "MultiSigTreasury: need at least 2 signers");
        require(signers.length <= 20, "MultiSigTreasury: too many signers");
        require(threshold >= 1 && threshold <= signers.length, "MultiSigTreasury: bad threshold");

        uint256 id = treasuries.length;

        // Validate and register signers
        for (uint256 i = 0; i < signers.length; i++) {
            require(signers[i] != address(0), "MultiSigTreasury: zero signer");
            require(!isSigner[id][signers[i]], "MultiSigTreasury: duplicate signer");
            isSigner[id][signers[i]] = true;
            treasuriesBySigner[signers[i]].push(id);
        }

        treasuries.push(Treasury({
            signers: signers,
            threshold: threshold,
            balance: 0,
            name: name,
            createdAt: block.timestamp
        }));

        emit TreasuryCreated(id, name, signers, threshold);
        return id;
    }

    function deposit(uint256 treasuryId) external payable {
        require(treasuryId < treasuries.length, "MultiSigTreasury: invalid treasury");
        require(msg.value > 0, "MultiSigTreasury: zero deposit");

        treasuries[treasuryId].balance += msg.value;
        emit Deposited(treasuryId, msg.sender, msg.value);
    }

    function propose(uint256 treasuryId, address recipient, uint256 amount, string calldata memo) external returns (uint256) {
        require(treasuryId < treasuries.length, "MultiSigTreasury: invalid treasury");
        Treasury storage t = treasuries[treasuryId];
        require(isSigner[treasuryId][msg.sender], "MultiSigTreasury: not a signer");
        require(recipient != address(0), "MultiSigTreasury: zero recipient");
        require(amount > 0 && amount <= t.balance, "MultiSigTreasury: bad amount");
        require(bytes(memo).length <= 300, "MultiSigTreasury: memo too long");

        uint256 id = proposals.length;
        proposals.push(Proposal({
            treasuryId: treasuryId,
            proposer: msg.sender,
            recipient: recipient,
            amount: amount,
            memo: memo,
            approvals: 1,
            executed: false,
            vetoed: false,
            createdAt: block.timestamp
        }));

        hasApproved[id][msg.sender] = true;
        proposalsByTreasury[treasuryId].push(id);

        emit ProposalCreated(id, treasuryId, recipient, amount, memo);
        emit ProposalApproved(id, msg.sender, 1);
        return id;
    }

    function approve(uint256 proposalId) external {
        require(proposalId < proposals.length, "MultiSigTreasury: invalid proposal");
        Proposal storage p = proposals[proposalId];
        require(isSigner[p.treasuryId][msg.sender], "MultiSigTreasury: not a signer");
        require(!p.executed && !p.vetoed, "MultiSigTreasury: already resolved");
        require(!hasApproved[proposalId][msg.sender], "MultiSigTreasury: already approved");

        hasApproved[proposalId][msg.sender] = true;
        p.approvals++;

        emit ProposalApproved(proposalId, msg.sender, p.approvals);

        Treasury storage t = treasuries[p.treasuryId];
        if (p.approvals >= t.threshold && !p.executed) {
            require(t.balance >= p.amount, "MultiSigTreasury: insufficient balance");
            p.executed = true;
            t.balance -= p.amount;

            (bool ok, ) = p.recipient.call{value: p.amount}("");
            require(ok, "MultiSigTreasury: transfer failed");
            emit ProposalExecuted(proposalId, p.recipient, p.amount);
        }
    }

    function veto(uint256 proposalId) external {
        require(proposalId < proposals.length, "MultiSigTreasury: invalid proposal");
        Proposal storage p = proposals[proposalId];
        require(isSigner[p.treasuryId][msg.sender], "MultiSigTreasury: not a signer");
        require(!p.executed && !p.vetoed, "MultiSigTreasury: already resolved");

        p.vetoed = true;
        emit ProposalVetoed(proposalId, msg.sender);
    }

    function getTreasury(uint256 id) external view returns (address[] memory signers, uint256 threshold, uint256 balance, string memory name, uint256 createdAt) {
        require(id < treasuries.length, "MultiSigTreasury: invalid id");
        Treasury memory t = treasuries[id];
        return (t.signers, t.threshold, t.balance, t.name, t.createdAt);
    }

    function getProposal(uint256 id) external view returns (
        uint256 treasuryId, address proposer, address recipient, uint256 amount,
        string memory memo, uint256 approvals, bool executed, bool vetoed
    ) {
        require(id < proposals.length, "MultiSigTreasury: invalid id");
        Proposal memory p = proposals[id];
        return (p.treasuryId, p.proposer, p.recipient, p.amount, p.memo, p.approvals, p.executed, p.vetoed);
    }

    function getProposalsByTreasury(uint256 id) external view returns (uint256[] memory) {
        return proposalsByTreasury[id];
    }

    function getTreasuriesBySigner(address account) external view returns (uint256[] memory) {
        return treasuriesBySigner[account];
    }

    function totalTreasuries() external view returns (uint256) {
        return treasuries.length;
    }
}
