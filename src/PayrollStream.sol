// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PayrollStream
/// @notice Employer deposits native USDC into a per-second linear stream for an employee.
///         The employee can withdraw whatever has accrued at any time. The employer can
///         top up the stream or end it early, paying out only what has accrued so far
///         and refunding the rest.
contract PayrollStream {
    struct Stream {
        address employer;
        address employee;
        uint256 ratePerSecond;
        uint256 deposited;
        uint256 withdrawn;
        uint256 startedAt;
        uint256 stoppedAt;
        bool active;
    }

    Stream[] public streams;
    mapping(address => uint256[]) public streamsByEmployer;
    mapping(address => uint256[]) public streamsByEmployee;

    event StreamCreated(uint256 indexed id, address indexed employer, address indexed employee, uint256 ratePerSecond, uint256 deposited);
    event Withdrawn(uint256 indexed id, address indexed employee, uint256 amount);
    event StreamToppedUp(uint256 indexed id, uint256 amount);
    event StreamStopped(uint256 indexed id, uint256 refundedAmount);

    function createStream(address employee, uint256 ratePerSecond) external payable returns (uint256) {
        require(employee != address(0), "PayrollStream: zero employee");
        require(employee != msg.sender, "PayrollStream: employee cannot be employer");
        require(ratePerSecond > 0, "PayrollStream: zero rate");
        require(msg.value > 0, "PayrollStream: must deposit funds");

        uint256 id = streams.length;
        streams.push(Stream({
            employer: msg.sender,
            employee: employee,
            ratePerSecond: ratePerSecond,
            deposited: msg.value,
            withdrawn: 0,
            startedAt: block.timestamp,
            stoppedAt: 0,
            active: true
        }));

        streamsByEmployer[msg.sender].push(id);
        streamsByEmployee[employee].push(id);

        emit StreamCreated(id, msg.sender, employee, ratePerSecond, msg.value);
        return id;
    }

    function _accrued(Stream memory s) internal view returns (uint256) {
        uint256 endTime = s.active ? block.timestamp : s.stoppedAt;
        uint256 elapsed = endTime - s.startedAt;
        uint256 owed = elapsed * s.ratePerSecond;
        uint256 cap = s.deposited;
        return owed > cap ? cap : owed;
    }

    function withdrawable(uint256 id) public view returns (uint256) {
        require(id < streams.length, "PayrollStream: invalid id");
        Stream memory s = streams[id];
        uint256 accrued = _accrued(s);
        return accrued > s.withdrawn ? accrued - s.withdrawn : 0;
    }

    function withdraw(uint256 id) external {
        require(id < streams.length, "PayrollStream: invalid id");
        Stream storage s = streams[id];
        require(msg.sender == s.employee, "PayrollStream: not the employee");

        uint256 amount = withdrawable(id);
        require(amount > 0, "PayrollStream: nothing to withdraw");

        s.withdrawn += amount;
        (bool ok, ) = s.employee.call{value: amount}("");
        require(ok, "PayrollStream: transfer failed");

        emit Withdrawn(id, s.employee, amount);
    }

    function topUp(uint256 id) external payable {
        require(id < streams.length, "PayrollStream: invalid id");
        Stream storage s = streams[id];
        require(msg.sender == s.employer, "PayrollStream: not the employer");
        require(s.active, "PayrollStream: stream not active");
        require(msg.value > 0, "PayrollStream: zero top up");

        s.deposited += msg.value;
        emit StreamToppedUp(id, msg.value);
    }

    function stopStream(uint256 id) external {
        require(id < streams.length, "PayrollStream: invalid id");
        Stream storage s = streams[id];
        require(msg.sender == s.employer, "PayrollStream: not the employer");
        require(s.active, "PayrollStream: already stopped");

        s.active = false;
        s.stoppedAt = block.timestamp;

        uint256 accrued = _accrued(s);
        uint256 refund = s.deposited - accrued;

        if (refund > 0) {
            (bool ok, ) = s.employer.call{value: refund}("");
            require(ok, "PayrollStream: refund failed");
            s.deposited = accrued;
        }

        emit StreamStopped(id, refund);
    }

    function getStream(uint256 id) external view returns (
        address employer,
        address employee,
        uint256 ratePerSecond,
        uint256 deposited,
        uint256 withdrawn,
        uint256 startedAt,
        uint256 stoppedAt,
        bool active
    ) {
        require(id < streams.length, "PayrollStream: invalid id");
        Stream memory s = streams[id];
        return (s.employer, s.employee, s.ratePerSecond, s.deposited, s.withdrawn, s.startedAt, s.stoppedAt, s.active);
    }

    function getStreamsByEmployer(address account) external view returns (uint256[] memory) {
        return streamsByEmployer[account];
    }

    function getStreamsByEmployee(address account) external view returns (uint256[] memory) {
        return streamsByEmployee[account];
    }

    function totalStreams() external view returns (uint256) {
        return streams.length;
    }
}
