// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ArbitratedEscrow
/// @notice Generic 2-party escrow with a neutral arbiter. Depositor locks native USDC.
///         Both parties can agree to release or refund. If they disagree, the arbiter
///         splits the funds in any ratio they choose. Arbiter fee is taken first.
contract ArbitratedEscrow {
    enum Status { Funded, Released, Refunded, Resolved }

    struct Escrow {
        address depositor;
        address beneficiary;
        address arbiter;
        uint256 amount;
        uint256 arbiterFeeBps;
        string description;
        uint256 createdAt;
        Status status;
        bool depositorApproved;
        bool beneficiaryApproved;
    }

    Escrow[] public escrows;
    mapping(address => uint256[]) public escrowsByDepositor;
    mapping(address => uint256[]) public escrowsByBeneficiary;

    event EscrowFunded(uint256 indexed id, address indexed depositor, address indexed beneficiary, address arbiter, uint256 amount);
    event ApprovalSet(uint256 indexed id, address indexed by, bool approved);
    event EscrowReleased(uint256 indexed id, uint256 toBeneficiary);
    event EscrowRefunded(uint256 indexed id, uint256 toDepositor);
    event EscrowResolved(uint256 indexed id, uint256 toDepositor, uint256 toBeneficiary, uint256 toArbiter);

    uint256 public constant MAX_ARBITER_FEE_BPS = 1000; // 10%

    function create(
        address beneficiary,
        address arbiter,
        string calldata description,
        uint256 arbiterFeeBps
    ) external payable returns (uint256) {
        require(beneficiary != address(0), "ArbitratedEscrow: zero beneficiary");
        require(arbiter != address(0), "ArbitratedEscrow: zero arbiter");
        require(beneficiary != msg.sender, "ArbitratedEscrow: depositor cannot be beneficiary");
        require(arbiter != msg.sender && arbiter != beneficiary, "ArbitratedEscrow: arbiter must be neutral");
        require(msg.value > 0, "ArbitratedEscrow: zero amount");
        require(arbiterFeeBps <= MAX_ARBITER_FEE_BPS, "ArbitratedEscrow: fee too high");
        require(bytes(description).length > 0, "ArbitratedEscrow: empty description");

        uint256 id = escrows.length;
        escrows.push(Escrow({
            depositor: msg.sender,
            beneficiary: beneficiary,
            arbiter: arbiter,
            amount: msg.value,
            arbiterFeeBps: arbiterFeeBps,
            description: description,
            createdAt: block.timestamp,
            status: Status.Funded,
            depositorApproved: false,
            beneficiaryApproved: false
        }));

        escrowsByDepositor[msg.sender].push(id);
        escrowsByBeneficiary[beneficiary].push(id);

        emit EscrowFunded(id, msg.sender, beneficiary, arbiter, msg.value);
        return id;
    }

    function approve(uint256 id) external {
        require(id < escrows.length, "ArbitratedEscrow: invalid id");
        Escrow storage e = escrows[id];
        require(e.status == Status.Funded, "ArbitratedEscrow: not active");
        require(msg.sender == e.depositor || msg.sender == e.beneficiary, "ArbitratedEscrow: not a participant");

        if (msg.sender == e.depositor) e.depositorApproved = true;
        else e.beneficiaryApproved = true;

        emit ApprovalSet(id, msg.sender, true);

        if (e.depositorApproved && e.beneficiaryApproved) {
            e.status = Status.Released;
            (bool ok, ) = e.beneficiary.call{value: e.amount}("");
            require(ok, "ArbitratedEscrow: transfer failed");
            emit EscrowReleased(id, e.amount);
        }
    }

    function requestRefund(uint256 id) external {
        require(id < escrows.length, "ArbitratedEscrow: invalid id");
        Escrow storage e = escrows[id];
        require(e.status == Status.Funded, "ArbitratedEscrow: not active");
        require(msg.sender == e.beneficiary, "ArbitratedEscrow: only beneficiary can initiate refund");

        e.status = Status.Refunded;
        (bool ok, ) = e.depositor.call{value: e.amount}("");
        require(ok, "ArbitratedEscrow: refund failed");
        emit EscrowRefunded(id, e.amount);
    }

    /// @notice Arbiter splits funds: depositorBps + beneficiaryBps must equal (10000 - arbiterFeeBps).
    function resolve(uint256 id, uint256 depositorBps, uint256 beneficiaryBps) external {
        require(id < escrows.length, "ArbitratedEscrow: invalid id");
        Escrow storage e = escrows[id];
        require(msg.sender == e.arbiter, "ArbitratedEscrow: not the arbiter");
        require(e.status == Status.Funded, "ArbitratedEscrow: not active");
        require(depositorBps + beneficiaryBps + e.arbiterFeeBps == 10000, "ArbitratedEscrow: bps must sum to 10000");

        e.status = Status.Resolved;

        uint256 toDepositor = (e.amount * depositorBps) / 10000;
        uint256 toBeneficiary = (e.amount * beneficiaryBps) / 10000;
        uint256 toArbiter = e.amount - toDepositor - toBeneficiary;

        if (toDepositor > 0) { (bool ok, ) = e.depositor.call{value: toDepositor}(""); require(ok, "ArbitratedEscrow: depositor transfer failed"); }
        if (toBeneficiary > 0) { (bool ok, ) = e.beneficiary.call{value: toBeneficiary}(""); require(ok, "ArbitratedEscrow: beneficiary transfer failed"); }
        if (toArbiter > 0) { (bool ok, ) = e.arbiter.call{value: toArbiter}(""); require(ok, "ArbitratedEscrow: arbiter transfer failed"); }

        emit EscrowResolved(id, toDepositor, toBeneficiary, toArbiter);
    }

    function getEscrow(uint256 id) external view returns (
        address depositor,
        address beneficiary,
        address arbiter,
        uint256 amount,
        uint256 arbiterFeeBps,
        string memory description,
        Status status,
        bool depositorApproved,
        bool beneficiaryApproved
    ) {
        require(id < escrows.length, "ArbitratedEscrow: invalid id");
        Escrow memory e = escrows[id];
        return (e.depositor, e.beneficiary, e.arbiter, e.amount, e.arbiterFeeBps, e.description, e.status, e.depositorApproved, e.beneficiaryApproved);
    }

    function getEscrowsByDepositor(address account) external view returns (uint256[] memory) {
        return escrowsByDepositor[account];
    }

    function getEscrowsByBeneficiary(address account) external view returns (uint256[] memory) {
        return escrowsByBeneficiary[account];
    }

    function totalEscrows() external view returns (uint256) {
        return escrows.length;
    }
}
