// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MilestoneEscrow
/// @notice Client funds a project upfront in native USDC. The project is split into
///         milestones with fixed amounts. The client approves each milestone individually
///         to release that tranche to the contractor. Either party can cancel before any
///         milestone is approved, refunding the client's remaining balance.
contract MilestoneEscrow {
    enum ProjectStatus { Active, Completed, Cancelled }

    struct Milestone {
        string description;
        uint256 amount;
        bool approved;
        bool paid;
    }

    struct Project {
        address client;
        address contractor;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 createdAt;
        ProjectStatus status;
    }

    Project[] public projects;
    mapping(uint256 => Milestone[]) public milestones;
    mapping(address => uint256[]) public projectsByClient;
    mapping(address => uint256[]) public projectsByContractor;

    event ProjectFunded(uint256 indexed id, address indexed client, address indexed contractor, uint256 totalAmount, uint256 milestoneCount);
    event MilestoneApproved(uint256 indexed projectId, uint256 indexed milestoneIndex, uint256 amount);
    event ProjectCompleted(uint256 indexed id);
    event ProjectCancelled(uint256 indexed id, uint256 refundedAmount);

    function createProject(
        address contractor,
        string[] calldata descriptions,
        uint256[] calldata amounts
    ) external payable returns (uint256) {
        require(contractor != address(0), "MilestoneEscrow: zero contractor");
        require(contractor != msg.sender, "MilestoneEscrow: contractor cannot be client");
        require(descriptions.length > 0, "MilestoneEscrow: need at least one milestone");
        require(descriptions.length == amounts.length, "MilestoneEscrow: length mismatch");
        require(descriptions.length <= 20, "MilestoneEscrow: too many milestones");

        uint256 sum = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(amounts[i] > 0, "MilestoneEscrow: zero milestone amount");
            sum += amounts[i];
        }
        require(msg.value == sum, "MilestoneEscrow: incorrect total funding");

        uint256 id = projects.length;
        projects.push(Project({
            client: msg.sender,
            contractor: contractor,
            totalAmount: sum,
            releasedAmount: 0,
            createdAt: block.timestamp,
            status: ProjectStatus.Active
        }));

        for (uint256 i = 0; i < descriptions.length; i++) {
            require(bytes(descriptions[i]).length > 0, "MilestoneEscrow: empty description");
            milestones[id].push(Milestone({
                description: descriptions[i],
                amount: amounts[i],
                approved: false,
                paid: false
            }));
        }

        projectsByClient[msg.sender].push(id);
        projectsByContractor[contractor].push(id);

        emit ProjectFunded(id, msg.sender, contractor, sum, descriptions.length);
        return id;
    }

    function approveMilestone(uint256 projectId, uint256 milestoneIndex) external {
        require(projectId < projects.length, "MilestoneEscrow: invalid project");
        Project storage p = projects[projectId];
        require(msg.sender == p.client, "MilestoneEscrow: not the client");
        require(p.status == ProjectStatus.Active, "MilestoneEscrow: not active");
        require(milestoneIndex < milestones[projectId].length, "MilestoneEscrow: invalid milestone");

        Milestone storage m = milestones[projectId][milestoneIndex];
        require(!m.paid, "MilestoneEscrow: already paid");

        m.approved = true;
        m.paid = true;
        p.releasedAmount += m.amount;

        (bool ok, ) = p.contractor.call{value: m.amount}("");
        require(ok, "MilestoneEscrow: transfer failed");

        emit MilestoneApproved(projectId, milestoneIndex, m.amount);

        if (p.releasedAmount == p.totalAmount) {
            p.status = ProjectStatus.Completed;
            emit ProjectCompleted(projectId);
        }
    }

    function cancelProject(uint256 projectId) external {
        require(projectId < projects.length, "MilestoneEscrow: invalid project");
        Project storage p = projects[projectId];
        require(msg.sender == p.client || msg.sender == p.contractor, "MilestoneEscrow: not a participant");
        require(p.status == ProjectStatus.Active, "MilestoneEscrow: not active");

        p.status = ProjectStatus.Cancelled;
        uint256 refund = p.totalAmount - p.releasedAmount;

        if (refund > 0) {
            (bool ok, ) = p.client.call{value: refund}("");
            require(ok, "MilestoneEscrow: refund failed");
        }

        emit ProjectCancelled(projectId, refund);
    }

    function getProject(uint256 id) external view returns (
        address client,
        address contractor,
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 createdAt,
        ProjectStatus status,
        uint256 milestoneCount
    ) {
        require(id < projects.length, "MilestoneEscrow: invalid id");
        Project memory p = projects[id];
        return (p.client, p.contractor, p.totalAmount, p.releasedAmount, p.createdAt, p.status, milestones[id].length);
    }

    function getMilestone(uint256 projectId, uint256 index) external view returns (string memory, uint256, bool, bool) {
        require(projectId < projects.length, "MilestoneEscrow: invalid project");
        require(index < milestones[projectId].length, "MilestoneEscrow: invalid milestone");
        Milestone memory m = milestones[projectId][index];
        return (m.description, m.amount, m.approved, m.paid);
    }

    function getProjectsByClient(address account) external view returns (uint256[] memory) {
        return projectsByClient[account];
    }

    function getProjectsByContractor(address account) external view returns (uint256[] memory) {
        return projectsByContractor[account];
    }

    function totalProjects() external view returns (uint256) {
        return projects.length;
    }
}
