// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrowdfundRefundable
/// @notice Campaign creator sets a funding goal and deadline. Backers pledge native USDC.
///         If the goal is met by the deadline, the creator withdraws. If not, every
///         backer can individually claim a full refund of their pledge.
contract CrowdfundRefundable {
    enum Status { Active, Succeeded, Failed, Withdrawn }

    struct Campaign {
        address creator;
        string title;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 raised;
        Status status;
        uint256 backerCount;
    }

    Campaign[] public campaigns;
    mapping(uint256 => mapping(address => uint256)) public pledged;
    mapping(address => uint256[]) public campaignsByCreator;

    event CampaignCreated(uint256 indexed id, address indexed creator, string title, uint256 goal, uint256 deadline);
    event Pledged(uint256 indexed id, address indexed backer, uint256 amount, uint256 totalRaised);
    event GoalReached(uint256 indexed id, uint256 totalRaised);
    event Withdrawn(uint256 indexed id, address indexed creator, uint256 amount);
    event Refunded(uint256 indexed id, address indexed backer, uint256 amount);

    uint256 public constant MIN_DURATION = 1 days;
    uint256 public constant MAX_DURATION = 180 days;

    function createCampaign(
        string calldata title,
        string calldata description,
        uint256 goal,
        uint256 duration
    ) external returns (uint256) {
        require(bytes(title).length > 0, "CrowdfundRefundable: empty title");
        require(bytes(description).length > 0 && bytes(description).length <= 1000, "CrowdfundRefundable: bad description");
        require(goal > 0, "CrowdfundRefundable: zero goal");
        require(duration >= MIN_DURATION && duration <= MAX_DURATION, "CrowdfundRefundable: bad duration");

        uint256 id = campaigns.length;
        campaigns.push(Campaign({
            creator: msg.sender,
            title: title,
            description: description,
            goal: goal,
            deadline: block.timestamp + duration,
            raised: 0,
            status: Status.Active,
            backerCount: 0
        }));

        campaignsByCreator[msg.sender].push(id);
        emit CampaignCreated(id, msg.sender, title, goal, block.timestamp + duration);
        return id;
    }

    function pledge(uint256 id) external payable {
        require(id < campaigns.length, "CrowdfundRefundable: invalid id");
        Campaign storage c = campaigns[id];
        require(c.status == Status.Active, "CrowdfundRefundable: not active");
        require(block.timestamp < c.deadline, "CrowdfundRefundable: deadline passed");
        require(msg.value > 0, "CrowdfundRefundable: zero pledge");

        if (pledged[id][msg.sender] == 0) c.backerCount++;
        pledged[id][msg.sender] += msg.value;
        c.raised += msg.value;

        emit Pledged(id, msg.sender, msg.value, c.raised);

        if (c.raised >= c.goal && c.status == Status.Active) {
            c.status = Status.Succeeded;
            emit GoalReached(id, c.raised);
        }
    }

    function withdraw(uint256 id) external {
        require(id < campaigns.length, "CrowdfundRefundable: invalid id");
        Campaign storage c = campaigns[id];
        require(msg.sender == c.creator, "CrowdfundRefundable: not creator");
        require(c.status == Status.Succeeded, "CrowdfundRefundable: goal not reached");

        c.status = Status.Withdrawn;
        uint256 amount = c.raised;

        (bool ok, ) = c.creator.call{value: amount}("");
        require(ok, "CrowdfundRefundable: transfer failed");
        emit Withdrawn(id, msg.sender, amount);
    }

    function finalizeFailed(uint256 id) external {
        require(id < campaigns.length, "CrowdfundRefundable: invalid id");
        Campaign storage c = campaigns[id];
        require(c.status == Status.Active, "CrowdfundRefundable: not active");
        require(block.timestamp >= c.deadline, "CrowdfundRefundable: deadline not passed");
        require(c.raised < c.goal, "CrowdfundRefundable: goal was met");
        c.status = Status.Failed;
    }

    function claimRefund(uint256 id) external {
        require(id < campaigns.length, "CrowdfundRefundable: invalid id");
        Campaign storage c = campaigns[id];
        require(c.status == Status.Failed, "CrowdfundRefundable: not failed");

        uint256 amount = pledged[id][msg.sender];
        require(amount > 0, "CrowdfundRefundable: nothing to refund");

        pledged[id][msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "CrowdfundRefundable: refund failed");
        emit Refunded(id, msg.sender, amount);
    }

    function getCampaign(uint256 id) external view returns (
        address creator,
        string memory title,
        string memory description,
        uint256 goal,
        uint256 deadline,
        uint256 raised,
        Status status,
        uint256 backerCount
    ) {
        require(id < campaigns.length, "CrowdfundRefundable: invalid id");
        Campaign memory c = campaigns[id];
        return (c.creator, c.title, c.description, c.goal, c.deadline, c.raised, c.status, c.backerCount);
    }

    function getCampaignsByCreator(address account) external view returns (uint256[] memory) {
        return campaignsByCreator[account];
    }

    function totalCampaigns() external view returns (uint256) {
        return campaigns.length;
    }
}
