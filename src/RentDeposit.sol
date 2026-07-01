// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title RentDeposit
/// @notice Tenant deposits a security deposit in native USDC for a lease. At end of lease,
///         the landlord can claim a documented deduction (with reason); the remainder is
///         automatically refundable to the tenant. If the landlord claims nothing, the
///         tenant can withdraw the full deposit after the lease end date.
contract RentDeposit {
    enum Status { Active, Settled }

    struct Lease {
        address tenant;
        address landlord;
        string propertyRef;
        uint256 depositAmount;
        uint256 leaseEndAt;
        uint256 deductionAmount;
        string deductionReason;
        bool deductionClaimed;
        Status status;
    }

    Lease[] public leases;
    mapping(address => uint256[]) public leasesByTenant;
    mapping(address => uint256[]) public leasesByLandlord;

    event LeaseCreated(uint256 indexed id, address indexed tenant, address indexed landlord, string propertyRef, uint256 depositAmount, uint256 leaseEndAt);
    event DeductionClaimed(uint256 indexed id, uint256 amount, string reason);
    event DepositSettled(uint256 indexed id, uint256 toLandlord, uint256 toTenant);

    function createLease(
        address landlord,
        string calldata propertyRef,
        uint256 leaseEndAt
    ) external payable returns (uint256) {
        require(landlord != address(0), "RentDeposit: zero landlord");
        require(landlord != msg.sender, "RentDeposit: tenant cannot be landlord");
        require(bytes(propertyRef).length > 0, "RentDeposit: empty property ref");
        require(leaseEndAt > block.timestamp, "RentDeposit: lease end must be future");
        require(msg.value > 0, "RentDeposit: zero deposit");

        uint256 id = leases.length;
        leases.push(Lease({
            tenant: msg.sender,
            landlord: landlord,
            propertyRef: propertyRef,
            depositAmount: msg.value,
            leaseEndAt: leaseEndAt,
            deductionAmount: 0,
            deductionReason: "",
            deductionClaimed: false,
            status: Status.Active
        }));

        leasesByTenant[msg.sender].push(id);
        leasesByLandlord[landlord].push(id);

        emit LeaseCreated(id, msg.sender, landlord, propertyRef, msg.value, leaseEndAt);
        return id;
    }

    /// @notice Landlord claims a deduction after lease end, before final settlement.
    function claimDeduction(uint256 id, uint256 amount, string calldata reason) external {
        require(id < leases.length, "RentDeposit: invalid id");
        Lease storage l = leases[id];
        require(msg.sender == l.landlord, "RentDeposit: not the landlord");
        require(l.status == Status.Active, "RentDeposit: already settled");
        require(block.timestamp >= l.leaseEndAt, "RentDeposit: lease not ended");
        require(!l.deductionClaimed, "RentDeposit: deduction already claimed");
        require(amount <= l.depositAmount, "RentDeposit: deduction exceeds deposit");
        require(bytes(reason).length > 0, "RentDeposit: empty reason");

        l.deductionAmount = amount;
        l.deductionReason = reason;
        l.deductionClaimed = true;

        emit DeductionClaimed(id, amount, reason);
    }

    /// @notice Either party can finalize settlement after lease end (and after any deduction claim window the landlord chooses to use).
    function settle(uint256 id) external {
        require(id < leases.length, "RentDeposit: invalid id");
        Lease storage l = leases[id];
        require(msg.sender == l.tenant || msg.sender == l.landlord, "RentDeposit: not a participant");
        require(l.status == Status.Active, "RentDeposit: already settled");
        require(block.timestamp >= l.leaseEndAt, "RentDeposit: lease not ended");

        l.status = Status.Settled;

        uint256 toLandlord = l.deductionAmount;
        uint256 toTenant = l.depositAmount - l.deductionAmount;

        if (toLandlord > 0) {
            (bool ok1, ) = l.landlord.call{value: toLandlord}("");
            require(ok1, "RentDeposit: landlord transfer failed");
        }
        if (toTenant > 0) {
            (bool ok2, ) = l.tenant.call{value: toTenant}("");
            require(ok2, "RentDeposit: tenant transfer failed");
        }

        emit DepositSettled(id, toLandlord, toTenant);
    }

    function getLease(uint256 id) external view returns (
        address tenant,
        address landlord,
        string memory propertyRef,
        uint256 depositAmount,
        uint256 leaseEndAt,
        uint256 deductionAmount,
        string memory deductionReason,
        Status status
    ) {
        require(id < leases.length, "RentDeposit: invalid id");
        Lease memory l = leases[id];
        return (l.tenant, l.landlord, l.propertyRef, l.depositAmount, l.leaseEndAt, l.deductionAmount, l.deductionReason, l.status);
    }

    function getLeasesByTenant(address account) external view returns (uint256[] memory) {
        return leasesByTenant[account];
    }

    function getLeasesByLandlord(address account) external view returns (uint256[] memory) {
        return leasesByLandlord[account];
    }

    function totalLeases() external view returns (uint256) {
        return leases.length;
    }
}
