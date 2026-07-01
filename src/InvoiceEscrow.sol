// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title InvoiceEscrow
/// @notice Vendor issues an invoice in native USDC. Payer funds it directly into the contract.
///         Funds release to the vendor when the payer confirms delivery, or automatically
///         after the auto-release deadline passes. Payer can dispute before auto-release,
///         freezing the funds until the vendor and payer settle manually via cancellation.
contract InvoiceEscrow {
    enum Status { Created, Funded, Released, Disputed, Cancelled }

    struct Invoice {
        address vendor;
        address payer;
        string description;
        uint256 amount;
        uint256 createdAt;
        uint256 fundedAt;
        uint256 autoReleaseAt;
        Status status;
    }

    Invoice[] public invoices;
    mapping(address => uint256[]) public invoicesByVendor;
    mapping(address => uint256[]) public invoicesByPayer;

    event InvoiceCreated(uint256 indexed id, address indexed vendor, address indexed payer, uint256 amount, string description);
    event InvoiceFunded(uint256 indexed id, uint256 amount, uint256 autoReleaseAt);
    event InvoiceReleased(uint256 indexed id, address indexed to, uint256 amount);
    event InvoiceDisputed(uint256 indexed id, address indexed by);
    event InvoiceCancelled(uint256 indexed id);

    uint256 public constant MIN_RELEASE_WINDOW = 1 days;
    uint256 public constant MAX_RELEASE_WINDOW = 180 days;

    function createInvoice(
        address payer,
        string calldata description,
        uint256 amount,
        uint256 releaseWindow
    ) external returns (uint256) {
        require(payer != address(0), "InvoiceEscrow: zero payer");
        require(payer != msg.sender, "InvoiceEscrow: vendor cannot be payer");
        require(amount > 0, "InvoiceEscrow: zero amount");
        require(bytes(description).length > 0, "InvoiceEscrow: empty description");
        require(releaseWindow >= MIN_RELEASE_WINDOW && releaseWindow <= MAX_RELEASE_WINDOW, "InvoiceEscrow: bad window");

        uint256 id = invoices.length;
        invoices.push(Invoice({
            vendor: msg.sender,
            payer: payer,
            description: description,
            amount: amount,
            createdAt: block.timestamp,
            fundedAt: 0,
            autoReleaseAt: 0,
            status: Status.Created
        }));

        invoicesByVendor[msg.sender].push(id);
        invoicesByPayer[payer].push(id);

        emit InvoiceCreated(id, msg.sender, payer, amount, description);
        return id;
    }

    function fund(uint256 id, uint256 releaseWindow) external payable {
        require(id < invoices.length, "InvoiceEscrow: invalid id");
        Invoice storage inv = invoices[id];
        require(msg.sender == inv.payer, "InvoiceEscrow: not the payer");
        require(inv.status == Status.Created, "InvoiceEscrow: not fundable");
        require(msg.value == inv.amount, "InvoiceEscrow: incorrect amount");
        require(releaseWindow >= MIN_RELEASE_WINDOW && releaseWindow <= MAX_RELEASE_WINDOW, "InvoiceEscrow: bad window");

        inv.status = Status.Funded;
        inv.fundedAt = block.timestamp;
        inv.autoReleaseAt = block.timestamp + releaseWindow;

        emit InvoiceFunded(id, msg.value, inv.autoReleaseAt);
    }

    function confirmDelivery(uint256 id) external {
        require(id < invoices.length, "InvoiceEscrow: invalid id");
        Invoice storage inv = invoices[id];
        require(msg.sender == inv.payer, "InvoiceEscrow: not the payer");
        require(inv.status == Status.Funded, "InvoiceEscrow: not funded");

        _release(id);
    }

    function claimAutoRelease(uint256 id) external {
        require(id < invoices.length, "InvoiceEscrow: invalid id");
        Invoice storage inv = invoices[id];
        require(inv.status == Status.Funded, "InvoiceEscrow: not funded");
        require(block.timestamp >= inv.autoReleaseAt, "InvoiceEscrow: too early");

        _release(id);
    }

    function _release(uint256 id) internal {
        Invoice storage inv = invoices[id];
        inv.status = Status.Released;
        uint256 amount = inv.amount;
        (bool ok, ) = inv.vendor.call{value: amount}("");
        require(ok, "InvoiceEscrow: transfer failed");
        emit InvoiceReleased(id, inv.vendor, amount);
    }

    function dispute(uint256 id) external {
        require(id < invoices.length, "InvoiceEscrow: invalid id");
        Invoice storage inv = invoices[id];
        require(msg.sender == inv.payer, "InvoiceEscrow: not the payer");
        require(inv.status == Status.Funded, "InvoiceEscrow: not funded");
        require(block.timestamp < inv.autoReleaseAt, "InvoiceEscrow: window closed");

        inv.status = Status.Disputed;
        emit InvoiceDisputed(id, msg.sender);
    }

    /// @notice Mutual cancellation after a dispute — refunds the payer. Requires vendor consent.
    function cancelAfterDispute(uint256 id) external {
        require(id < invoices.length, "InvoiceEscrow: invalid id");
        Invoice storage inv = invoices[id];
        require(msg.sender == inv.vendor, "InvoiceEscrow: not the vendor");
        require(inv.status == Status.Disputed, "InvoiceEscrow: not disputed");

        inv.status = Status.Cancelled;
        uint256 amount = inv.amount;
        (bool ok, ) = inv.payer.call{value: amount}("");
        require(ok, "InvoiceEscrow: refund failed");
        emit InvoiceCancelled(id);
    }

    function getInvoice(uint256 id) external view returns (
        address vendor,
        address payer,
        string memory description,
        uint256 amount,
        uint256 createdAt,
        uint256 fundedAt,
        uint256 autoReleaseAt,
        Status status
    ) {
        require(id < invoices.length, "InvoiceEscrow: invalid id");
        Invoice memory inv = invoices[id];
        return (inv.vendor, inv.payer, inv.description, inv.amount, inv.createdAt, inv.fundedAt, inv.autoReleaseAt, inv.status);
    }

    function getInvoicesByVendor(address account) external view returns (uint256[] memory) {
        return invoicesByVendor[account];
    }

    function getInvoicesByPayer(address account) external view returns (uint256[] memory) {
        return invoicesByPayer[account];
    }

    function totalInvoices() external view returns (uint256) {
        return invoices.length;
    }
}
