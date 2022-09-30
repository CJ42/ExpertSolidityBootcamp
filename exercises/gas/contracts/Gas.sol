// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./Ownable.sol";

contract GasContract is Ownable {

    event SupplyChanged(address indexed, uint256);

    event Transfer(address recipient, uint256 amount);

    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount
    );

    event WhiteListTransfer(address indexed);

    event AddedToWhitelist(address userAddress, uint256 tier);

    
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }

    struct History {
        uint256 lastUpdate;
        address updatedBy;
    }

    struct Payment {
        // word 1
        uint256 paymentID; // ---> 32 bytes
        // word 2
        PaymentType paymentType; // ---> 1 byte
        bool adminUpdated;  // --> 1 byte
        address admin; // administrators address ---> 20 bytes
        // word 3
        address recipient;  // --> 20 bytes
        // word 4
        uint256 amount; // --> 32 bytes
        // word 5
        string recipientName; // max 8 characters
    }

    struct ImportantStruct {
        uint128 valueA; // max 3 digits (can fit together in the same slot)
        uint128 valueB; // max 3 digits (can fit together in the same slot)
        uint256 bigValue;
    }

    uint256 constant TRADE_FLAG = 1;
    uint256 constant DIVIDEND_FLAG = 1;    

    uint256 immutable public totalSupply; // cannot be updated
    
    mapping(address => uint256) private balances;
    mapping(address => Payment[]) private payments;
    mapping(address => ImportantStruct) private whiteListStruct;
    History[] private paymentHistory; // when a payment was updated
    
    address[5] public administrators;
    mapping(address => uint256) public whitelist;

    
    modifier onlyAdminOrOwner() {
        require(msg.sender == owner() || checkForAdmin(msg.sender), "only owner or admin");
        _;
    }

    modifier checkIfWhiteListed {
        uint256 usersTier = whitelist[msg.sender];
        require(
            usersTier > 0,
            "msg.sender user is not whitelisted"
        );
        require(
            usersTier < 4,
            "incorrect user's tier, tier can only be 1, 2 or 3;"
        );
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
        emit SupplyChanged(msg.sender, totalSupply_);
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
        return TRADE_FLAG == 1 || DIVIDEND_FLAG == 1;
    }

    function addHistory(address _updateAddress)
        public
    {
        paymentHistory.push(
            History({
                lastUpdate: block.timestamp,
                updatedBy: _updateAddress
            })
        );
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
        require(balances[msg.sender] >= _amount, "GasContract:transfer: insufficent balance");
        require(
            bytes(_name).length < 9,
            "GasContract:transfer: recipient name too long (max 8 characters)"
        );

        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;

        emit Transfer(_recipient, _amount);

        Payment memory payment = Payment({
            admin: address(0),
            adminUpdated: false,
            paymentType: PaymentType.BasicPayment,
            recipient: _recipient,
            amount: _amount,
            recipientName: _name,
            paymentID: payments[msg.sender].length + 1
        });
        payments[msg.sender].push(payment);
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdminOrOwner {

        require(_ID != 0, "GasContract:updatePayment: _ID cannot be zero");
        require(_amount != 0, "GasContract:updatePayment: _amount cannot be zero");

        require(
            _user != address(0),
            "GasContract:updatePayment: _user cannot be be address(0)"
        );

        uint256 totalUserPayments = payments[_user].length;

        Payment storage payment;

        for (uint256 ii = 0; ii < totalUserPayments; ++ii) {

            payment = payments[_user][ii];

            if (payment.paymentID == _ID) {

                payment.paymentType = _type;
                payment.adminUpdated = true;
                payment.admin = _user;
                payment.amount = _amount;

                addHistory(_user);

                emit PaymentUpdated(
                    msg.sender,
                    _ID,
                    _amount
                );
                return;
            }
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier)
        public
        onlyAdminOrOwner
    {
        uint256 value = whitelist[_userAddrs];

        assembly {
            switch _tier
            case 1 {
                value := 1
            }
            case 2 {
                value := 2
            }
            default {
                value := 3
            }
        }

        whitelist[_userAddrs] = value;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount,
        ImportantStruct memory _struct
    ) public checkIfWhiteListed {
        require(balances[msg.sender] >= _amount, "GasContract:whiteTransfer: insufficient balance");
        require(
            _amount > 3,
            "GasContract:whiteTransfer: minimum _amount required = 3"
        );

        uint256 whitelistSenderAmount = whitelist[msg.sender];
        
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        balances[msg.sender] += whitelistSenderAmount;
        balances[_recipient] -= whitelistSenderAmount;

        whiteListStruct[msg.sender] = _struct;
        emit WhiteListTransfer(_recipient);
    }
}
