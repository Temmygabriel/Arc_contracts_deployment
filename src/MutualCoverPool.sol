// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MutualCoverPool
/// @notice Members pay a cover premium into a shared pool. A member who suffers a defined
///         loss submits a claim. An admin-approved claim pays out from the pool. Members
///         can withdraw their pro-rata share if they exit and no claim is pending.
contract MutualCoverPool {
    enum ClaimStatus { Pending, Approved, Rejected }

    struct Pool {
        address admin;
        string coverType;
        uint256 balance;
        uint256 totalContributed;
        uint256 memberCount;
        uint256 createdAt;
    }

    struct CoverClaim {
        uint256 poolId;
        address claimant;
        string description;
        uint256 amountRequested;
        uint256 submittedAt;
        ClaimStatus status;
        string adminNote;
    }

    Pool[] public pools;
    CoverClaim[] public coverClaims;

    mapping(uint256 => mapping(address => bool)) public isMember;
    mapping(uint256 => mapping(address => uint256)) public memberContributions;
    mapping(uint256 => address[]) public poolMembers;
    mapping(uint256 => uint256[]) public claimsByPool;
    mapping(address => uint256[]) public poolsByMember;
    mapping(address => uint256[]) public claimsByMember;

    event PoolCreated(uint256 indexed id, address indexed admin, string coverType);
    event MemberJoined(uint256 indexed poolId, address indexed member, uint256 premium);
    event PremiumPaid(uint256 indexed poolId, address indexed member, uint256 amount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed poolId, address indexed claimant, uint256 amountRequested);
    event ClaimApproved(uint256 indexed claimId, uint256 amount);
    event ClaimRejected(uint256 indexed claimId, string note);
    event MemberExited(uint256 indexed poolId, address indexed member, uint256 refund);

    function createPool(string calldata coverType) external returns (uint256) {
        require(bytes(coverType).length > 0, "MutualCoverPool: empty cover type");

        uint256 id = pools.length;
        pools.push(Pool({
            admin: msg.sender,
            coverType: coverType,
            balance: 0,
            totalContributed: 0,
            memberCount: 0,
            createdAt: block.timestamp
        }));

        emit PoolCreated(id, msg.sender, coverType);
        return id;
    }

    function joinPool(uint256 poolId) external payable {
        require(poolId < pools.length, "MutualCoverPool: invalid pool");
        require(!isMember[poolId][msg.sender], "MutualCoverPool: already a member");
        require(msg.value > 0, "MutualCoverPool: zero premium");

        isMember[poolId][msg.sender] = true;
        memberContributions[poolId][msg.sender] = msg.value;
        poolMembers[poolId].push(msg.sender);
        poolsByMember[msg.sender].push(poolId);
        pools[poolId].balance += msg.value;
        pools[poolId].totalContributed += msg.value;
        pools[poolId].memberCount++;

        emit MemberJoined(poolId, msg.sender, msg.value);
    }

    function payPremium(uint256 poolId) external payable {
        require(poolId < pools.length, "MutualCoverPool: invalid pool");
        require(isMember[poolId][msg.sender], "MutualCoverPool: not a member");
        require(msg.value > 0, "MutualCoverPool: zero premium");

        memberContributions[poolId][msg.sender] += msg.value;
        pools[poolId].balance += msg.value;
        pools[poolId].totalContributed += msg.value;

        emit PremiumPaid(poolId, msg.sender, msg.value);
    }

    function submitClaim(uint256 poolId, string calldata description, uint256 amountRequested) external returns (uint256) {
        require(poolId < pools.length, "MutualCoverPool: invalid pool");
        require(isMember[poolId][msg.sender], "MutualCoverPool: not a member");
        require(bytes(description).length > 0 && bytes(description).length <= 500, "MutualCoverPool: bad description");
        require(amountRequested > 0 && amountRequested <= pools[poolId].balance, "MutualCoverPool: bad amount");

        uint256 id = coverClaims.length;
        coverClaims.push(CoverClaim({
            poolId: poolId,
            claimant: msg.sender,
            description: description,
            amountRequested: amountRequested,
            submittedAt: block.timestamp,
            status: ClaimStatus.Pending,
            adminNote: ""
        }));

        claimsByPool[poolId].push(id);
        claimsByMember[msg.sender].push(id);

        emit ClaimSubmitted(id, poolId, msg.sender, amountRequested);
        return id;
    }

    function approveClaim(uint256 claimId, string calldata note) external {
        require(claimId < coverClaims.length, "MutualCoverPool: invalid claim");
        CoverClaim storage c = coverClaims[claimId];
        Pool storage p = pools[c.poolId];
        require(msg.sender == p.admin, "MutualCoverPool: not admin");
        require(c.status == ClaimStatus.Pending, "MutualCoverPool: not pending");
        require(p.balance >= c.amountRequested, "MutualCoverPool: insufficient pool balance");

        c.status = ClaimStatus.Approved;
        c.adminNote = note;
        p.balance -= c.amountRequested;

        (bool ok, ) = c.claimant.call{value: c.amountRequested}("");
        require(ok, "MutualCoverPool: transfer failed");

        emit ClaimApproved(claimId, c.amountRequested);
    }

    function rejectClaim(uint256 claimId, string calldata note) external {
        require(claimId < coverClaims.length, "MutualCoverPool: invalid claim");
        CoverClaim storage c = coverClaims[claimId];
        require(msg.sender == pools[c.poolId].admin, "MutualCoverPool: not admin");
        require(c.status == ClaimStatus.Pending, "MutualCoverPool: not pending");

        c.status = ClaimStatus.Rejected;
        c.adminNote = note;

        emit ClaimRejected(claimId, note);
    }

    function exitPool(uint256 poolId) external {
        require(poolId < pools.length, "MutualCoverPool: invalid pool");
        require(isMember[poolId][msg.sender], "MutualCoverPool: not a member");
        Pool storage p = pools[poolId];
        require(p.memberCount > 0, "MutualCoverPool: empty pool");

        uint256 contributed = memberContributions[poolId][msg.sender];
        uint256 proRataShare = (p.balance * contributed) / p.totalContributed;

        isMember[poolId][msg.sender] = false;
        memberContributions[poolId][msg.sender] = 0;
        p.memberCount--;
        p.balance -= proRataShare;

        if (proRataShare > 0) {
            (bool ok, ) = msg.sender.call{value: proRataShare}("");
            require(ok, "MutualCoverPool: exit transfer failed");
        }

        emit MemberExited(poolId, msg.sender, proRataShare);
    }

    function getPool(uint256 id) external view returns (address, string memory, uint256, uint256, uint256, uint256) {
        require(id < pools.length, "MutualCoverPool: invalid id");
        Pool memory p = pools[id];
        return (p.admin, p.coverType, p.balance, p.totalContributed, p.memberCount, p.createdAt);
    }

    function getClaim(uint256 id) external view returns (
        uint256 poolId, address claimant, string memory description,
        uint256 amountRequested, ClaimStatus status, string memory adminNote
    ) {
        require(id < coverClaims.length, "MutualCoverPool: invalid id");
        CoverClaim memory c = coverClaims[id];
        return (c.poolId, c.claimant, c.description, c.amountRequested, c.status, c.adminNote);
    }

    function getPoolsByMember(address account) external view returns (uint256[] memory) {
        return poolsByMember[account];
    }

    function totalPools() external view returns (uint256) {
        return pools.length;
    }
}
