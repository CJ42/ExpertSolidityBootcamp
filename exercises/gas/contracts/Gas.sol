// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "./Ownable.sol";

error NotAdminOrOwner();
error NotWhitelisted();
error IncorrectTier();
error InsufficientBalance(uint256 balance, uint256 amount);
error RecipientNameTooLong();
error InvalidPaymentId();
error InvalidPaymentAmount();
error InvalidPaymentUser();
error WhiteTransferInsufficientBalance();
error WhiteTransferAmountToSmall();


contract GasContract is Ownable {

    event Transfer(address recipient, uint256 amount);

    
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend
    }

    struct Payment {
        // word 1
        uint256 paymentID; // ---> 32 bytes
        // word 2
        PaymentType paymentType; // ---> 1 byte
        bytes8 recipientName; // max 8 characters
        address recipient;  // --> 20 bytes
        // word 3
        uint256 amount; // --> 32 bytes
    }

    struct ImportantStruct {
        uint128 valueA; // max 3 digits (can fit together in the same slot)
        uint128 valueB; // max 3 digits (can fit together in the same slot)
        uint256 bigValue;
    }

    uint256 immutable public totalSupply; // cannot be updated
    
    mapping(address => uint256) private balances;
    mapping(address => Payment[]) private payments;
    
    address[5] public administrators;
    mapping(address => uint256) public whitelist;

    
    modifier onlyAdminOrOwner() {
        _onlyOwnerOrAdmin();
        _;
    }

    constructor(address[5] memory admins_, uint256 totalSupply_) {
        // owner is set as msg.sender in the Ownable constructor, so use msg.sender instead of reading storage
        // it's also likely not necessary to store it in a local variable, as it might end up in more stack manipulation (using SWAP, DUP, etc...)
        // using the CALLER opcode is easier and more straight forward
        totalSupply = totalSupply_;
        balances[msg.sender] = totalSupply_;
        // no need to loop, both are fixed size array of 5 x addresses (address[5])
        administrators = admins_;
    }

    function checkForAdmin(address _user) public view returns (bool admin_) {
        uint256 ii;
        do {
            if (administrators[ii] == _user) return true;
            unchecked { ++ii; }
        } while (ii < 5);
        return false;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        return balances[_user];
    }

    function getTradingMode() public pure returns (bool mode_) {
        return true;
    }

    function getPayments(address _user)
        public
        view
        returns (Payment[] memory payments_)
    {
        return payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public {
        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance(balances[msg.sender], _amount);
        }

        if (bytes(_name).length > 8) {
            revert RecipientNameTooLong();
        }

        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;

        emit Transfer(_recipient, _amount);

        payments[msg.sender].push(
            Payment({
                paymentID: payments[msg.sender].length + 1,
                paymentType: PaymentType.BasicPayment,
                recipient: _recipient,
                amount: _amount,
                recipientName: bytes8(bytes(_name))
            })
        );
    }


    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdminOrOwner {

        if (_ID == 0) revert InvalidPaymentId();
        if (_amount == 0) revert InvalidPaymentAmount();
        if (_user == address(0)) revert InvalidPaymentUser();

        uint256 totalUserPayments = payments[_user].length;

        Payment storage payment;

        uint256 ii;
        while (ii < totalUserPayments) {

            payment = payments[_user][ii];

            if (payment.paymentID == _ID) {

                payment.paymentType = _type;
                payment.amount = _amount;

                return;
            }

            unchecked { ++ii; }
        }

    }

    function addToWhitelist(address _userAddrs, uint256 _tier)
        public
        onlyAdminOrOwner
    {
        whitelist[_userAddrs] = _tier;
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount,
        ImportantStruct calldata
    ) public {
        uint256 usersTier = whitelist[msg.sender];
        if (usersTier == 0) revert NotWhitelisted();
        if (usersTier > 4) revert IncorrectTier();

        if (balances[msg.sender] < _amount) revert WhiteTransferInsufficientBalance();
        if (_amount < 4) revert WhiteTransferAmountToSmall();

        uint256 cumulatedAmount = (_amount > usersTier)
            ? _amount - usersTier
            : usersTier - _amount;
            
        balances[msg.sender] -= cumulatedAmount;
        balances[_recipient] += cumulatedAmount;
    }

    function _onlyOwnerOrAdmin() internal view {
        if (msg.sender != owner() && !checkForAdmin(msg.sender)) {
            revert NotAdminOrOwner();
        }
    }
}
