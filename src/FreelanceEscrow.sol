// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title FreelanceEscrow
/// @notice Streamlined 1:1 freelance escrow. Client funds the job upfront in native USDC.
///         Client releases on approval or both parties agree to cancel for a refund.
///         Either party can request cancellation; the other must confirm. No arbiter —
///         designed for trusted freelance relationships where speed matters.
contract FreelanceEscrow {
    enum JobStatus { Funded, Completed, CancelRequested, Cancelled }

    struct Job {
        address client;
        address freelancer;
        string description;
        uint256 amount;
        uint256 fundedAt;
        JobStatus status;
        address cancelRequestedBy;
    }

    Job[] public jobs;
    mapping(address => uint256[]) public jobsByClient;
    mapping(address => uint256[]) public jobsByFreelancer;

    event JobFunded(uint256 indexed id, address indexed client, address indexed freelancer, uint256 amount, string description);
    event JobCompleted(uint256 indexed id, address indexed freelancer, uint256 amount);
    event CancelRequested(uint256 indexed id, address indexed requestedBy);
    event JobCancelled(uint256 indexed id, uint256 refundedAmount);

    function fundJob(
        address freelancer,
        string calldata description
    ) external payable returns (uint256) {
        require(freelancer != address(0), "FreelanceEscrow: zero freelancer");
        require(freelancer != msg.sender, "FreelanceEscrow: client cannot be freelancer");
        require(msg.value > 0, "FreelanceEscrow: zero amount");
        require(bytes(description).length > 0 && bytes(description).length <= 500, "FreelanceEscrow: bad description");

        uint256 id = jobs.length;
        jobs.push(Job({
            client: msg.sender,
            freelancer: freelancer,
            description: description,
            amount: msg.value,
            fundedAt: block.timestamp,
            status: JobStatus.Funded,
            cancelRequestedBy: address(0)
        }));

        jobsByClient[msg.sender].push(id);
        jobsByFreelancer[freelancer].push(id);

        emit JobFunded(id, msg.sender, freelancer, msg.value, description);
        return id;
    }

    function approve(uint256 id) external {
        require(id < jobs.length, "FreelanceEscrow: invalid id");
        Job storage j = jobs[id];
        require(msg.sender == j.client, "FreelanceEscrow: not the client");
        require(j.status == JobStatus.Funded, "FreelanceEscrow: not in funded state");

        j.status = JobStatus.Completed;
        (bool ok, ) = j.freelancer.call{value: j.amount}("");
        require(ok, "FreelanceEscrow: transfer failed");
        emit JobCompleted(id, j.freelancer, j.amount);
    }

    function requestCancel(uint256 id) external {
        require(id < jobs.length, "FreelanceEscrow: invalid id");
        Job storage j = jobs[id];
        require(msg.sender == j.client || msg.sender == j.freelancer, "FreelanceEscrow: not a participant");
        require(j.status == JobStatus.Funded, "FreelanceEscrow: not in funded state");

        j.status = JobStatus.CancelRequested;
        j.cancelRequestedBy = msg.sender;
        emit CancelRequested(id, msg.sender);
    }

    function confirmCancel(uint256 id) external {
        require(id < jobs.length, "FreelanceEscrow: invalid id");
        Job storage j = jobs[id];
        require(j.status == JobStatus.CancelRequested, "FreelanceEscrow: no cancel pending");
        require(msg.sender == j.client || msg.sender == j.freelancer, "FreelanceEscrow: not a participant");
        require(msg.sender != j.cancelRequestedBy, "FreelanceEscrow: must be confirmed by the other party");

        j.status = JobStatus.Cancelled;
        (bool ok, ) = j.client.call{value: j.amount}("");
        require(ok, "FreelanceEscrow: refund failed");
        emit JobCancelled(id, j.amount);
    }

    function getJob(uint256 id) external view returns (
        address client,
        address freelancer,
        string memory description,
        uint256 amount,
        uint256 fundedAt,
        JobStatus status
    ) {
        require(id < jobs.length, "FreelanceEscrow: invalid id");
        Job memory j = jobs[id];
        return (j.client, j.freelancer, j.description, j.amount, j.fundedAt, j.status);
    }

    function getJobsByClient(address account) external view returns (uint256[] memory) {
        return jobsByClient[account];
    }

    function getJobsByFreelancer(address account) external view returns (uint256[] memory) {
        return jobsByFreelancer[account];
    }

    function totalJobs() external view returns (uint256) {
        return jobs.length;
    }
}
