// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title GrantDisbursement
/// @notice Grantor deposits native USDC as a grant. Recipient submits work claims
///         with proof. Grantor approves or rejects each claim for partial disbursement.
///         Unclaimed funds can be reclaimed by the grantor after a deadline.
contract GrantDisbursement {
    enum GrantStatus { Active, Exhausted, Reclaimed }
    enum ClaimStatus { Pending, Approved, Rejected }

    struct Grant {
        address grantor;
        address recipient;
        string purpose;
        uint256 totalAmount;
        uint256 disbursed;
        uint256 deadline;
        GrantStatus status;
        uint256 claimCount;
    }

    struct Claim {
        uint256 grantId;
        address claimant;
        string proof;
        uint256 amountRequested;
        uint256 submittedAt;
        ClaimStatus status;
        string rejectionReason;
    }

    Grant[] public grants;
    Claim[] public claims;

    mapping(uint256 => uint256[]) public claimsByGrant;
    mapping(address => uint256[]) public grantsByGrantor;
    mapping(address => uint256[]) public grantsByRecipient;
    mapping(address => uint256[]) public claimsByClaimant;

    event GrantCreated(uint256 indexed id, address indexed grantor, address indexed recipient, uint256 amount, uint256 deadline);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed grantId, address indexed claimant, uint256 amountRequested);
    event ClaimApproved(uint256 indexed claimId, uint256 amount);
    event ClaimRejected(uint256 indexed claimId, string reason);
    event GrantReclaimed(uint256 indexed grantId, uint256 amount);

    function createGrant(address recipient, string calldata purpose, uint256 deadline) external payable returns (uint256) {
        require(recipient != address(0), "GrantDisbursement: zero recipient");
        require(recipient != msg.sender, "GrantDisbursement: grantor cannot be recipient");
        require(bytes(purpose).length > 0 && bytes(purpose).length <= 500, "GrantDisbursement: bad purpose");
        require(msg.value > 0, "GrantDisbursement: zero amount");
        require(deadline > block.timestamp, "GrantDisbursement: deadline in past");

        uint256 id = grants.length;
        grants.push(Grant({
            grantor: msg.sender,
            recipient: recipient,
            purpose: purpose,
            totalAmount: msg.value,
            disbursed: 0,
            deadline: deadline,
            status: GrantStatus.Active,
            claimCount: 0
        }));

        grantsByGrantor[msg.sender].push(id);
        grantsByRecipient[recipient].push(id);

        emit GrantCreated(id, msg.sender, recipient, msg.value, deadline);
        return id;
    }

    function submitClaim(uint256 grantId, string calldata proof, uint256 amountRequested) external returns (uint256) {
        require(grantId < grants.length, "GrantDisbursement: invalid grant");
        Grant storage g = grants[grantId];
        require(msg.sender == g.recipient, "GrantDisbursement: not the recipient");
        require(g.status == GrantStatus.Active, "GrantDisbursement: grant not active");
        require(block.timestamp < g.deadline, "GrantDisbursement: deadline passed");
        require(bytes(proof).length > 0 && bytes(proof).length <= 500, "GrantDisbursement: bad proof");
        require(amountRequested > 0 && amountRequested <= g.totalAmount - g.disbursed, "GrantDisbursement: bad amount");

        uint256 id = claims.length;
        claims.push(Claim({
            grantId: grantId,
            claimant: msg.sender,
            proof: proof,
            amountRequested: amountRequested,
            submittedAt: block.timestamp,
            status: ClaimStatus.Pending,
            rejectionReason: ""
        }));

        claimsByGrant[grantId].push(id);
        claimsByClaimant[msg.sender].push(id);
        g.claimCount++;

        emit ClaimSubmitted(id, grantId, msg.sender, amountRequested);
        return id;
    }

    function approveClaim(uint256 claimId) external {
        require(claimId < claims.length, "GrantDisbursement: invalid claim");
        Claim storage c = claims[claimId];
        Grant storage g = grants[c.grantId];
        require(msg.sender == g.grantor, "GrantDisbursement: not the grantor");
        require(c.status == ClaimStatus.Pending, "GrantDisbursement: not pending");
        require(g.status == GrantStatus.Active, "GrantDisbursement: grant not active");

        c.status = ClaimStatus.Approved;
        g.disbursed += c.amountRequested;

        if (g.disbursed == g.totalAmount) g.status = GrantStatus.Exhausted;

        (bool ok, ) = c.claimant.call{value: c.amountRequested}("");
        require(ok, "GrantDisbursement: transfer failed");

        emit ClaimApproved(claimId, c.amountRequested);
    }

    function rejectClaim(uint256 claimId, string calldata reason) external {
        require(claimId < claims.length, "GrantDisbursement: invalid claim");
        Claim storage c = claims[claimId];
        Grant storage g = grants[c.grantId];
        require(msg.sender == g.grantor, "GrantDisbursement: not the grantor");
        require(c.status == ClaimStatus.Pending, "GrantDisbursement: not pending");

        c.status = ClaimStatus.Rejected;
        c.rejectionReason = reason;

        emit ClaimRejected(claimId, reason);
    }

    function reclaimUnspent(uint256 grantId) external {
        require(grantId < grants.length, "GrantDisbursement: invalid grant");
        Grant storage g = grants[grantId];
        require(msg.sender == g.grantor, "GrantDisbursement: not the grantor");
        require(g.status == GrantStatus.Active, "GrantDisbursement: not active");
        require(block.timestamp >= g.deadline, "GrantDisbursement: deadline not reached");

        g.status = GrantStatus.Reclaimed;
        uint256 remaining = g.totalAmount - g.disbursed;
        require(remaining > 0, "GrantDisbursement: nothing to reclaim");

        (bool ok, ) = g.grantor.call{value: remaining}("");
        require(ok, "GrantDisbursement: reclaim failed");

        emit GrantReclaimed(grantId, remaining);
    }

    function getGrant(uint256 id) external view returns (
        address grantor, address recipient, string memory purpose,
        uint256 totalAmount, uint256 disbursed, uint256 deadline,
        GrantStatus status, uint256 claimCount
    ) {
        require(id < grants.length, "GrantDisbursement: invalid id");
        Grant memory g = grants[id];
        return (g.grantor, g.recipient, g.purpose, g.totalAmount, g.disbursed, g.deadline, g.status, g.claimCount);
    }

    function getClaim(uint256 id) external view returns (
        uint256 grantId, address claimant, string memory proof,
        uint256 amountRequested, ClaimStatus status, string memory rejectionReason
    ) {
        require(id < claims.length, "GrantDisbursement: invalid id");
        Claim memory c = claims[id];
        return (c.grantId, c.claimant, c.proof, c.amountRequested, c.status, c.rejectionReason);
    }

    function getClaimsByGrant(uint256 id) external view returns (uint256[] memory) {
        return claimsByGrant[id];
    }

    function getGrantsByGrantor(address account) external view returns (uint256[] memory) {
        return grantsByGrantor[account];
    }

    function totalGrants() external view returns (uint256) {
        return grants.length;
    }
}
