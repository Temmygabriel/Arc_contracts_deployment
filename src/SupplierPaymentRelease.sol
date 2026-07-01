// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SupplierPaymentRelease
/// @notice Buyer locks native USDC for a purchase order. An authorized confirmer
///         (logistics agent, inspector, or oracle wallet) signals delivery confirmation.
///         Once confirmed, the supplier can release their payment. Buyer can cancel
///         before confirmation if delivery hasn't happened.
contract SupplierPaymentRelease {
    enum OrderStatus { Locked, Confirmed, Released, Cancelled }

    struct PurchaseOrder {
        address buyer;
        address supplier;
        address confirmer;
        string itemRef;
        uint256 amount;
        uint256 lockedAt;
        uint256 confirmedAt;
        uint256 releaseDeadline;
        OrderStatus status;
        string confirmationNote;
    }

    PurchaseOrder[] public orders;
    mapping(address => uint256[]) public ordersByBuyer;
    mapping(address => uint256[]) public ordersBySupplier;

    event OrderLocked(uint256 indexed id, address indexed buyer, address indexed supplier, address confirmer, uint256 amount, string itemRef);
    event DeliveryConfirmed(uint256 indexed id, address indexed confirmer, string note);
    event PaymentReleased(uint256 indexed id, address indexed supplier, uint256 amount);
    event OrderCancelled(uint256 indexed id, uint256 refundedAmount);

    function lockPayment(
        address supplier,
        address confirmer,
        string calldata itemRef,
        uint256 releaseDeadline
    ) external payable returns (uint256) {
        require(supplier != address(0), "SupplierPaymentRelease: zero supplier");
        require(supplier != msg.sender, "SupplierPaymentRelease: buyer cannot be supplier");
        require(confirmer != address(0), "SupplierPaymentRelease: zero confirmer");
        require(msg.value > 0, "SupplierPaymentRelease: zero amount");
        require(bytes(itemRef).length > 0, "SupplierPaymentRelease: empty item ref");
        require(releaseDeadline > block.timestamp, "SupplierPaymentRelease: deadline in past");

        uint256 id = orders.length;
        orders.push(PurchaseOrder({
            buyer: msg.sender,
            supplier: supplier,
            confirmer: confirmer,
            itemRef: itemRef,
            amount: msg.value,
            lockedAt: block.timestamp,
            confirmedAt: 0,
            releaseDeadline: releaseDeadline,
            status: OrderStatus.Locked,
            confirmationNote: ""
        }));

        ordersByBuyer[msg.sender].push(id);
        ordersBySupplier[supplier].push(id);

        emit OrderLocked(id, msg.sender, supplier, confirmer, msg.value, itemRef);
        return id;
    }

    function confirmDelivery(uint256 id, string calldata note) external {
        require(id < orders.length, "SupplierPaymentRelease: invalid id");
        PurchaseOrder storage o = orders[id];
        require(msg.sender == o.confirmer, "SupplierPaymentRelease: not the confirmer");
        require(o.status == OrderStatus.Locked, "SupplierPaymentRelease: not locked");
        require(block.timestamp <= o.releaseDeadline, "SupplierPaymentRelease: past deadline");

        o.status = OrderStatus.Confirmed;
        o.confirmedAt = block.timestamp;
        o.confirmationNote = note;

        emit DeliveryConfirmed(id, msg.sender, note);
    }

    function releasePayment(uint256 id) external {
        require(id < orders.length, "SupplierPaymentRelease: invalid id");
        PurchaseOrder storage o = orders[id];
        require(msg.sender == o.supplier, "SupplierPaymentRelease: not the supplier");
        require(o.status == OrderStatus.Confirmed, "SupplierPaymentRelease: not confirmed");

        o.status = OrderStatus.Released;
        (bool ok, ) = o.supplier.call{value: o.amount}("");
        require(ok, "SupplierPaymentRelease: transfer failed");

        emit PaymentReleased(id, o.supplier, o.amount);
    }

    function cancelOrder(uint256 id) external {
        require(id < orders.length, "SupplierPaymentRelease: invalid id");
        PurchaseOrder storage o = orders[id];
        require(msg.sender == o.buyer, "SupplierPaymentRelease: not the buyer");
        require(o.status == OrderStatus.Locked, "SupplierPaymentRelease: can only cancel while locked");

        o.status = OrderStatus.Cancelled;
        (bool ok, ) = o.buyer.call{value: o.amount}("");
        require(ok, "SupplierPaymentRelease: refund failed");

        emit OrderCancelled(id, o.amount);
    }

    function getOrder(uint256 id) external view returns (
        address buyer,
        address supplier,
        address confirmer,
        string memory itemRef,
        uint256 amount,
        uint256 lockedAt,
        uint256 confirmedAt,
        uint256 releaseDeadline,
        OrderStatus status,
        string memory confirmationNote
    ) {
        require(id < orders.length, "SupplierPaymentRelease: invalid id");
        PurchaseOrder memory o = orders[id];
        return (o.buyer, o.supplier, o.confirmer, o.itemRef, o.amount, o.lockedAt, o.confirmedAt, o.releaseDeadline, o.status, o.confirmationNote);
    }

    function getOrdersByBuyer(address account) external view returns (uint256[] memory) {
        return ordersByBuyer[account];
    }

    function getOrdersBySupplier(address account) external view returns (uint256[] memory) {
        return ordersBySupplier[account];
    }

    function totalOrders() external view returns (uint256) {
        return orders.length;
    }
}
