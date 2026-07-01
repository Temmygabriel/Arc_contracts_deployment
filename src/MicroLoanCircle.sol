// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MicroLoanCircle
/// @notice Members contribute to a shared lending pool. Any member can request a loan
///         up to a cap. The admin approves or rejects. Borrower repays principal +
///         interest. Interest goes back to the pool, growing it for everyone.
contract MicroLoanCircle {
    enum LoanStatus { Requested, Active, Repaid, Defaulted, Rejected }

    struct Pool {
        address admin;
        string name;
        uint256 balance;
        uint256 memberCount;
        uint256 totalLoaned;
        uint256 totalRepaid;
    }

    struct Loan {
        uint256 poolId;
        address borrower;
        uint256 principal;
        uint256 interestBps;
        uint256 dueAt;
        uint256 repaidAt;
        uint256 totalDue;
        LoanStatus status;
        string purpose;
    }

    Pool[] public pools;
    Loan[] public loans;

    mapping(uint256 => mapping(address => bool)) public isPoolMember;
    mapping(uint256 => address[]) public poolMembers;
    mapping(uint256 => mapping(address => uint256)) public memberContributions;
    mapping(uint256 => uint256[]) public loansByPool;
    mapping(address => uint256[]) public loansByBorrower;
    mapping(address => uint256[]) public poolsByMember;

    event PoolCreated(uint256 indexed id, address indexed admin, string name);
    event Contributed(uint256 indexed poolId, address indexed member, uint256 amount);
    event LoanRequested(uint256 indexed loanId, uint256 indexed poolId, address indexed borrower, uint256 principal, string purpose);
    event LoanApproved(uint256 indexed loanId, uint256 dueAt, uint256 totalDue);
    event LoanRejected(uint256 indexed loanId);
    event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanDefaulted(uint256 indexed loanId);

    uint256 public constant MAX_MEMBERS = 50;
    uint256 public constant MAX_INTEREST_BPS = 2000; // 20%

    function createPool(string calldata name, address[] calldata members) external returns (uint256) {
        require(bytes(name).length > 0, "MicroLoanCircle: empty name");
        require(members.length > 0 && members.length < MAX_MEMBERS, "MicroLoanCircle: bad member count");

        uint256 id = pools.length;
        pools.push(Pool({ admin: msg.sender, name: name, balance: 0, memberCount: members.length + 1, totalLoaned: 0, totalRepaid: 0 }));

        isPoolMember[id][msg.sender] = true;
        poolMembers[id].push(msg.sender);
        poolsByMember[msg.sender].push(id);

        for (uint256 i = 0; i < members.length; i++) {
            require(members[i] != address(0) && !isPoolMember[id][members[i]], "MicroLoanCircle: bad member");
            isPoolMember[id][members[i]] = true;
            poolMembers[id].push(members[i]);
            poolsByMember[members[i]].push(id);
        }

        emit PoolCreated(id, msg.sender, name);
        return id;
    }

    function contribute(uint256 poolId) external payable {
        require(poolId < pools.length, "MicroLoanCircle: invalid pool");
        require(isPoolMember[poolId][msg.sender], "MicroLoanCircle: not a member");
        require(msg.value > 0, "MicroLoanCircle: zero contribution");

        pools[poolId].balance += msg.value;
        memberContributions[poolId][msg.sender] += msg.value;
        emit Contributed(poolId, msg.sender, msg.value);
    }

    function requestLoan(
        uint256 poolId,
        uint256 principal,
        string calldata purpose
    ) external returns (uint256) {
        require(poolId < pools.length, "MicroLoanCircle: invalid pool");
        require(isPoolMember[poolId][msg.sender], "MicroLoanCircle: not a member");
        require(principal > 0, "MicroLoanCircle: zero principal");
        require(bytes(purpose).length > 0 && bytes(purpose).length <= 300, "MicroLoanCircle: bad purpose");

        uint256 id = loans.length;
        loans.push(Loan({
            poolId: poolId,
            borrower: msg.sender,
            principal: principal,
            interestBps: 0,
            dueAt: 0,
            repaidAt: 0,
            totalDue: 0,
            status: LoanStatus.Requested,
            purpose: purpose
        }));

        loansByPool[poolId].push(id);
        loansByBorrower[msg.sender].push(id);

        emit LoanRequested(id, poolId, msg.sender, principal, purpose);
        return id;
    }

    function approveLoan(uint256 loanId, uint256 interestBps, uint256 durationSeconds) external {
        require(loanId < loans.length, "MicroLoanCircle: invalid loan");
        Loan storage l = loans[loanId];
        require(msg.sender == pools[l.poolId].admin, "MicroLoanCircle: not admin");
        require(l.status == LoanStatus.Requested, "MicroLoanCircle: not requested");
        require(interestBps <= MAX_INTEREST_BPS, "MicroLoanCircle: interest too high");
        require(durationSeconds >= 1 days, "MicroLoanCircle: duration too short");
        require(pools[l.poolId].balance >= l.principal, "MicroLoanCircle: insufficient pool balance");

        l.interestBps = interestBps;
        l.dueAt = block.timestamp + durationSeconds;
        l.totalDue = l.principal + (l.principal * interestBps) / 10000;
        l.status = LoanStatus.Active;

        pools[l.poolId].balance -= l.principal;
        pools[l.poolId].totalLoaned += l.principal;

        (bool ok, ) = l.borrower.call{value: l.principal}("");
        require(ok, "MicroLoanCircle: disbursement failed");

        emit LoanApproved(loanId, l.dueAt, l.totalDue);
    }

    function rejectLoan(uint256 loanId) external {
        require(loanId < loans.length, "MicroLoanCircle: invalid loan");
        Loan storage l = loans[loanId];
        require(msg.sender == pools[l.poolId].admin, "MicroLoanCircle: not admin");
        require(l.status == LoanStatus.Requested, "MicroLoanCircle: not requested");

        l.status = LoanStatus.Rejected;
        emit LoanRejected(loanId);
    }

    function repay(uint256 loanId) external payable {
        require(loanId < loans.length, "MicroLoanCircle: invalid loan");
        Loan storage l = loans[loanId];
        require(msg.sender == l.borrower, "MicroLoanCircle: not the borrower");
        require(l.status == LoanStatus.Active, "MicroLoanCircle: not active");
        require(msg.value == l.totalDue, "MicroLoanCircle: incorrect repayment amount");

        l.status = LoanStatus.Repaid;
        l.repaidAt = block.timestamp;

        pools[l.poolId].balance += msg.value;
        pools[l.poolId].totalRepaid += l.principal;

        emit LoanRepaid(loanId, msg.sender, msg.value);
    }

    function markDefaulted(uint256 loanId) external {
        require(loanId < loans.length, "MicroLoanCircle: invalid loan");
        Loan storage l = loans[loanId];
        require(msg.sender == pools[l.poolId].admin, "MicroLoanCircle: not admin");
        require(l.status == LoanStatus.Active, "MicroLoanCircle: not active");
        require(block.timestamp > l.dueAt, "MicroLoanCircle: not overdue");

        l.status = LoanStatus.Defaulted;
        emit LoanDefaulted(loanId);
    }

    function getPool(uint256 id) external view returns (address, string memory, uint256, uint256, uint256, uint256) {
        require(id < pools.length, "MicroLoanCircle: invalid id");
        Pool memory p = pools[id];
        return (p.admin, p.name, p.balance, p.memberCount, p.totalLoaned, p.totalRepaid);
    }

    function getLoan(uint256 id) external view returns (
        uint256 poolId, address borrower, uint256 principal, uint256 interestBps,
        uint256 dueAt, uint256 totalDue, LoanStatus status, string memory purpose
    ) {
        require(id < loans.length, "MicroLoanCircle: invalid id");
        Loan memory l = loans[id];
        return (l.poolId, l.borrower, l.principal, l.interestBps, l.dueAt, l.totalDue, l.status, l.purpose);
    }

    function getLoansByPool(uint256 poolId) external view returns (uint256[] memory) {
        return loansByPool[poolId];
    }

    function getLoansByBorrower(address account) external view returns (uint256[] memory) {
        return loansByBorrower[account];
    }

    function getPoolsByMember(address account) external view returns (uint256[] memory) {
        return poolsByMember[account];
    }

    function totalPools() external view returns (uint256) {
        return pools.length;
    }
}
