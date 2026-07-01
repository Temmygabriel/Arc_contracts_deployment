// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ServiceLevelBond
/// @notice Service provider posts a native USDC bond before starting a contract.
///         If the provider meets their SLA, the client releases the bond back.
///         If the SLA is violated, the client can slash up to the pre-agreed slash amount.
///         An admin/oracle can also adjudicate if both parties disagree.
contract ServiceLevelBond {
    enum BondStatus { Active, Released, Slashed, Adjudicated }

    struct Bond {
        address provider;
        address client;
        address adjudicator;
        string slaDescription;
        uint256 bondAmount;
        uint256 maxSlashAmount;
        uint256 contractEndsAt;
        BondStatus status;
        uint256 slashedAmount;
        string slashReason;
    }

    Bond[] public bonds;
    mapping(address => uint256[]) public bondsByProvider;
    mapping(address => uint256[]) public bondsByClient;

    event BondPosted(uint256 indexed id, address indexed provider, address indexed client, uint256 bondAmount, uint256 maxSlashAmount, uint256 contractEndsAt);
    event BondReleased(uint256 indexed id, address indexed provider, uint256 amount);
    event BondSlashed(uint256 indexed id, address indexed client, uint256 slashedAmount, string reason);
    event BondAdjudicated(uint256 indexed id, uint256 toProvider, uint256 toClient);

    function postBond(
        address client,
        address adjudicator,
        string calldata slaDescription,
        uint256 maxSlashAmount,
        uint256 contractDuration
    ) external payable returns (uint256) {
        require(client != address(0), "ServiceLevelBond: zero client");
        require(client != msg.sender, "ServiceLevelBond: provider cannot be client");
        require(adjudicator != address(0), "ServiceLevelBond: zero adjudicator");
        require(adjudicator != msg.sender && adjudicator != client, "ServiceLevelBond: adjudicator must be neutral");
        require(msg.value > 0, "ServiceLevelBond: zero bond");
        require(maxSlashAmount <= msg.value, "ServiceLevelBond: slash exceeds bond");
        require(bytes(slaDescription).length > 0 && bytes(slaDescription).length <= 500, "ServiceLevelBond: bad SLA");
        require(contractDuration >= 1 days, "ServiceLevelBond: duration too short");

        uint256 id = bonds.length;
        bonds.push(Bond({
            provider: msg.sender,
            client: client,
            adjudicator: adjudicator,
            slaDescription: slaDescription,
            bondAmount: msg.value,
            maxSlashAmount: maxSlashAmount,
            contractEndsAt: block.timestamp + contractDuration,
            status: BondStatus.Active,
            slashedAmount: 0,
            slashReason: ""
        }));

        bondsByProvider[msg.sender].push(id);
        bondsByClient[client].push(id);

        emit BondPosted(id, msg.sender, client, msg.value, maxSlashAmount, block.timestamp + contractDuration);
        return id;
    }

    function releaseBond(uint256 id) external {
        require(id < bonds.length, "ServiceLevelBond: invalid id");
        Bond storage b = bonds[id];
        require(msg.sender == b.client, "ServiceLevelBond: not the client");
        require(b.status == BondStatus.Active, "ServiceLevelBond: not active");

        b.status = BondStatus.Released;
        uint256 amount = b.bondAmount;

        (bool ok, ) = b.provider.call{value: amount}("");
        require(ok, "ServiceLevelBond: release failed");
        emit BondReleased(id, b.provider, amount);
    }

    function slashBond(uint256 id, uint256 slashAmount, string calldata reason) external {
        require(id < bonds.length, "ServiceLevelBond: invalid id");
        Bond storage b = bonds[id];
        require(msg.sender == b.client, "ServiceLevelBond: not the client");
        require(b.status == BondStatus.Active, "ServiceLevelBond: not active");
        require(slashAmount > 0 && slashAmount <= b.maxSlashAmount, "ServiceLevelBond: invalid slash amount");
        require(bytes(reason).length > 0, "ServiceLevelBond: empty reason");

        b.status = BondStatus.Slashed;
        b.slashedAmount = slashAmount;
        b.slashReason = reason;

        uint256 toClient = slashAmount;
        uint256 toProvider = b.bondAmount - slashAmount;

        if (toClient > 0) {
            (bool ok1, ) = b.client.call{value: toClient}("");
            require(ok1, "ServiceLevelBond: client transfer failed");
        }
        if (toProvider > 0) {
            (bool ok2, ) = b.provider.call{value: toProvider}("");
            require(ok2, "ServiceLevelBond: provider transfer failed");
        }

        emit BondSlashed(id, msg.sender, slashAmount, reason);
    }

    function adjudicate(uint256 id, uint256 toProviderBps) external {
        require(id < bonds.length, "ServiceLevelBond: invalid id");
        Bond storage b = bonds[id];
        require(msg.sender == b.adjudicator, "ServiceLevelBond: not the adjudicator");
        require(b.status == BondStatus.Active, "ServiceLevelBond: not active");
        require(toProviderBps <= 10000, "ServiceLevelBond: bad bps");

        b.status = BondStatus.Adjudicated;

        uint256 toProvider = (b.bondAmount * toProviderBps) / 10000;
        uint256 toClient = b.bondAmount - toProvider;

        if (toProvider > 0) { (bool ok1, ) = b.provider.call{value: toProvider}(""); require(ok1, "ServiceLevelBond: provider payout failed"); }
        if (toClient > 0) { (bool ok2, ) = b.client.call{value: toClient}(""); require(ok2, "ServiceLevelBond: client payout failed"); }

        emit BondAdjudicated(id, toProvider, toClient);
    }

    function getBond(uint256 id) external view returns (
        address provider,
        address client,
        address adjudicator,
        string memory slaDescription,
        uint256 bondAmount,
        uint256 maxSlashAmount,
        uint256 contractEndsAt,
        BondStatus status,
        uint256 slashedAmount,
        string memory slashReason
    ) {
        require(id < bonds.length, "ServiceLevelBond: invalid id");
        Bond memory b = bonds[id];
        return (b.provider, b.client, b.adjudicator, b.slaDescription, b.bondAmount, b.maxSlashAmount, b.contractEndsAt, b.status, b.slashedAmount, b.slashReason);
    }

    function getBondsByProvider(address account) external view returns (uint256[] memory) {
        return bondsByProvider[account];
    }

    function getBondsByClient(address account) external view returns (uint256[] memory) {
        return bondsByClient[account];
    }

    function totalBonds() external view returns (uint256) {
        return bonds.length;
    }
}
