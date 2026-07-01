// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title VestingVault
/// @notice Lock native USDC for a beneficiary with a cliff and linear vesting schedule.
///         Before the cliff, nothing can be withdrawn. After the cliff, tokens unlock
///         linearly until the end of the vesting period. Grantor can revoke unvested
///         funds at any time (useful for employee/contractor vesting).
contract VestingVault {
    struct Vest {
        address grantor;
        address beneficiary;
        uint256 totalAmount;
        uint256 withdrawn;
        uint256 startAt;
        uint256 cliffAt;
        uint256 endAt;
        bool revoked;
        string label;
    }

    Vest[] public vests;
    mapping(address => uint256[]) public vestsByGrantor;
    mapping(address => uint256[]) public vestsByBeneficiary;

    event VestCreated(uint256 indexed id, address indexed grantor, address indexed beneficiary, uint256 amount, uint256 cliffAt, uint256 endAt, string label);
    event Withdrawn(uint256 indexed id, address indexed beneficiary, uint256 amount);
    event VestRevoked(uint256 indexed id, address indexed grantor, uint256 reclaimedAmount);

    function create(
        address beneficiary,
        uint256 cliffDuration,
        uint256 vestDuration,
        string calldata label
    ) external payable returns (uint256) {
        require(beneficiary != address(0), "VestingVault: zero beneficiary");
        require(beneficiary != msg.sender, "VestingVault: grantor cannot be beneficiary");
        require(msg.value > 0, "VestingVault: zero amount");
        require(vestDuration > 0, "VestingVault: zero duration");
        require(cliffDuration <= vestDuration, "VestingVault: cliff after vest end");

        uint256 id = vests.length;
        uint256 startAt = block.timestamp;

        vests.push(Vest({
            grantor: msg.sender,
            beneficiary: beneficiary,
            totalAmount: msg.value,
            withdrawn: 0,
            startAt: startAt,
            cliffAt: startAt + cliffDuration,
            endAt: startAt + vestDuration,
            revoked: false,
            label: label
        }));

        vestsByGrantor[msg.sender].push(id);
        vestsByBeneficiary[beneficiary].push(id);

        emit VestCreated(id, msg.sender, beneficiary, msg.value, startAt + cliffDuration, startAt + vestDuration, label);
        return id;
    }

    function vestedAmount(uint256 id) public view returns (uint256) {
        require(id < vests.length, "VestingVault: invalid id");
        Vest memory v = vests[id];

        if (v.revoked || block.timestamp < v.cliffAt) return 0;
        if (block.timestamp >= v.endAt) return v.totalAmount;

        uint256 elapsed = block.timestamp - v.startAt;
        uint256 total = v.endAt - v.startAt;
        return (v.totalAmount * elapsed) / total;
    }

    function withdrawable(uint256 id) public view returns (uint256) {
        require(id < vests.length, "VestingVault: invalid id");
        Vest memory v = vests[id];
        uint256 vested = vestedAmount(id);
        return vested > v.withdrawn ? vested - v.withdrawn : 0;
    }

    function withdraw(uint256 id) external {
        require(id < vests.length, "VestingVault: invalid id");
        Vest storage v = vests[id];
        require(msg.sender == v.beneficiary, "VestingVault: not the beneficiary");
        require(!v.revoked, "VestingVault: vest revoked");

        uint256 amount = withdrawable(id);
        require(amount > 0, "VestingVault: nothing to withdraw");

        v.withdrawn += amount;
        (bool ok, ) = v.beneficiary.call{value: amount}("");
        require(ok, "VestingVault: transfer failed");
        emit Withdrawn(id, msg.sender, amount);
    }

    function revoke(uint256 id) external {
        require(id < vests.length, "VestingVault: invalid id");
        Vest storage v = vests[id];
        require(msg.sender == v.grantor, "VestingVault: not the grantor");
        require(!v.revoked, "VestingVault: already revoked");

        v.revoked = true;

        uint256 vested = vestedAmount(id);
        // Pay out what has vested but not yet withdrawn
        uint256 toSend = vested > v.withdrawn ? vested - v.withdrawn : 0;
        if (toSend > 0) {
            v.withdrawn += toSend;
            (bool ok1, ) = v.beneficiary.call{value: toSend}("");
            require(ok1, "VestingVault: beneficiary transfer failed");
        }

        uint256 reclaim = v.totalAmount - v.withdrawn;
        if (reclaim > 0) {
            (bool ok2, ) = v.grantor.call{value: reclaim}("");
            require(ok2, "VestingVault: reclaim failed");
        }

        emit VestRevoked(id, msg.sender, reclaim);
    }

    function getVest(uint256 id) external view returns (
        address grantor,
        address beneficiary,
        uint256 totalAmount,
        uint256 withdrawn,
        uint256 startAt,
        uint256 cliffAt,
        uint256 endAt,
        bool revoked,
        string memory label
    ) {
        require(id < vests.length, "VestingVault: invalid id");
        Vest memory v = vests[id];
        return (v.grantor, v.beneficiary, v.totalAmount, v.withdrawn, v.startAt, v.cliffAt, v.endAt, v.revoked, v.label);
    }

    function getVestsByGrantor(address account) external view returns (uint256[] memory) {
        return vestsByGrantor[account];
    }

    function getVestsByBeneficiary(address account) external view returns (uint256[] memory) {
        return vestsByBeneficiary[account];
    }

    function totalVests() external view returns (uint256) {
        return vests.length;
    }
}
