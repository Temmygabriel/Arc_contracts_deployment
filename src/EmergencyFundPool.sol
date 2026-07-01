// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title EmergencyFundPool
/// @notice Members contribute native USDC to a shared emergency fund. Any member can
///         open a payout request with a stated reason and amount. Other members vote
///         yes or no within a voting window. Majority yes releases the funds to the
///         requester. The pool admin can veto within the same window.
contract EmergencyFundPool {
    struct Pool {
        address admin;
        string name;
        uint256 balance;
        uint256 memberCount;
        uint256 createdAt;
    }

    struct Request {
        uint256 poolId;
        address requester;
        string reason;
        uint256 amount;
        uint256 createdAt;
        uint256 votingEndsAt;
        uint256 yesVotes;
        uint256 noVotes;
        bool executed;
        bool vetoed;
    }

    Pool[] public pools;
    Request[] public requests;

    mapping(uint256 => mapping(address => bool)) public isPoolMember;
    mapping(uint256 => address[]) public poolMembers;
    mapping(uint256 => mapping(address => uint256)) public memberContributions;
    mapping(uint256 => mapping(address => bool)) public hasVotedOnRequest;
    mapping(uint256 => uint256[]) public requestsByPool;
    mapping(address => uint256[]) public poolsByMember;

    event PoolCreated(uint256 indexed id, address indexed admin, string name);
    event MemberJoined(uint256 indexed poolId, address indexed member, uint256 contributed);
    event ContributionAdded(uint256 indexed poolId, address indexed member, uint256 amount, uint256 newBalance);
    event RequestOpened(uint256 indexed requestId, uint256 indexed poolId, address indexed requester, uint256 amount);
    event VoteCast(uint256 indexed requestId, address indexed voter, bool support);
    event RequestExecuted(uint256 indexed requestId, address indexed requester, uint256 amount);
    event RequestVetoed(uint256 indexed requestId, address indexed admin);
    event RequestRejected(uint256 indexed requestId);

    uint256 public constant VOTING_WINDOW = 3 days;
    uint256 public constant MAX_MEMBERS = 50;

    function createPool(string calldata name, address[] calldata initialMembers) external returns (uint256) {
        require(bytes(name).length > 0, "EmergencyFundPool: empty name");
        require(initialMembers.length > 0, "EmergencyFundPool: need members");
        require(initialMembers.length < MAX_MEMBERS, "EmergencyFundPool: too many members");

        uint256 id = pools.length;
        pools.push(Pool({
            admin: msg.sender,
            name: name,
            balance: 0,
            memberCount: initialMembers.length + 1,
            createdAt: block.timestamp
        }));

        isPoolMember[id][msg.sender] = true;
        poolMembers[id].push(msg.sender);
        poolsByMember[msg.sender].push(id);

        for (uint256 i = 0; i < initialMembers.length; i++) {
            require(initialMembers[i] != address(0), "EmergencyFundPool: zero address");
            require(!isPoolMember[id][initialMembers[i]], "EmergencyFundPool: duplicate member");
            isPoolMember[id][initialMembers[i]] = true;
            poolMembers[id].push(initialMembers[i]);
            poolsByMember[initialMembers[i]].push(id);
        }

        emit PoolCreated(id, msg.sender, name);
        return id;
    }

    function contribute(uint256 poolId) external payable {
        require(poolId < pools.length, "EmergencyFundPool: invalid pool");
        require(isPoolMember[poolId][msg.sender], "EmergencyFundPool: not a member");
        require(msg.value > 0, "EmergencyFundPool: zero contribution");

        pools[poolId].balance += msg.value;
        memberContributions[poolId][msg.sender] += msg.value;

        emit ContributionAdded(poolId, msg.sender, msg.value, pools[poolId].balance);
    }

    function openRequest(uint256 poolId, string calldata reason, uint256 amount) external returns (uint256) {
        require(poolId < pools.length, "EmergencyFundPool: invalid pool");
        require(isPoolMember[poolId][msg.sender], "EmergencyFundPool: not a member");
        require(amount > 0 && amount <= pools[poolId].balance, "EmergencyFundPool: bad amount");
        require(bytes(reason).length > 0 && bytes(reason).length <= 500, "EmergencyFundPool: bad reason");

        uint256 id = requests.length;
        requests.push(Request({
            poolId: poolId,
            requester: msg.sender,
            reason: reason,
            amount: amount,
            createdAt: block.timestamp,
            votingEndsAt: block.timestamp + VOTING_WINDOW,
            yesVotes: 0,
            noVotes: 0,
            executed: false,
            vetoed: false
        }));

        requestsByPool[poolId].push(id);
        emit RequestOpened(id, poolId, msg.sender, amount);
        return id;
    }

    function vote(uint256 requestId, bool support) external {
        require(requestId < requests.length, "EmergencyFundPool: invalid request");
        Request storage r = requests[requestId];
        require(isPoolMember[r.poolId][msg.sender], "EmergencyFundPool: not a member");
        require(msg.sender != r.requester, "EmergencyFundPool: requester cannot vote");
        require(block.timestamp < r.votingEndsAt, "EmergencyFundPool: voting closed");
        require(!r.executed && !r.vetoed, "EmergencyFundPool: already resolved");
        require(!hasVotedOnRequest[requestId][msg.sender], "EmergencyFundPool: already voted");

        hasVotedOnRequest[requestId][msg.sender] = true;
        if (support) r.yesVotes++; else r.noVotes++;

        emit VoteCast(requestId, msg.sender, support);
    }

    function executeRequest(uint256 requestId) external {
        require(requestId < requests.length, "EmergencyFundPool: invalid request");
        Request storage r = requests[requestId];
        require(block.timestamp >= r.votingEndsAt, "EmergencyFundPool: voting open");
        require(!r.executed && !r.vetoed, "EmergencyFundPool: already resolved");
        require(r.yesVotes > r.noVotes, "EmergencyFundPool: not approved");
        require(pools[r.poolId].balance >= r.amount, "EmergencyFundPool: insufficient pool balance");

        r.executed = true;
        pools[r.poolId].balance -= r.amount;

        (bool ok, ) = r.requester.call{value: r.amount}("");
        require(ok, "EmergencyFundPool: transfer failed");
        emit RequestExecuted(requestId, r.requester, r.amount);
    }

    function vetoRequest(uint256 requestId) external {
        require(requestId < requests.length, "EmergencyFundPool: invalid request");
        Request storage r = requests[requestId];
        require(msg.sender == pools[r.poolId].admin, "EmergencyFundPool: not admin");
        require(block.timestamp < r.votingEndsAt, "EmergencyFundPool: voting closed");
        require(!r.executed && !r.vetoed, "EmergencyFundPool: already resolved");

        r.vetoed = true;
        emit RequestVetoed(requestId, msg.sender);
    }

    function getPool(uint256 id) external view returns (address, string memory, uint256, uint256, uint256) {
        require(id < pools.length, "EmergencyFundPool: invalid id");
        Pool memory p = pools[id];
        return (p.admin, p.name, p.balance, p.memberCount, p.createdAt);
    }

    function getRequest(uint256 id) external view returns (
        uint256 poolId, address requester, string memory reason, uint256 amount,
        uint256 votingEndsAt, uint256 yesVotes, uint256 noVotes, bool executed, bool vetoed
    ) {
        require(id < requests.length, "EmergencyFundPool: invalid id");
        Request memory r = requests[id];
        return (r.poolId, r.requester, r.reason, r.amount, r.votingEndsAt, r.yesVotes, r.noVotes, r.executed, r.vetoed);
    }

    function getPoolMembers(uint256 id) external view returns (address[] memory) {
        return poolMembers[id];
    }

    function getPoolsByMember(address account) external view returns (uint256[] memory) {
        return poolsByMember[account];
    }

    function totalPools() external view returns (uint256) {
        return pools.length;
    }
}
