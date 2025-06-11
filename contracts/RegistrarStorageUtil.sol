// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract RegistrarStorageUtil {
    mapping(address => address) public tokenPriceFeed;
    mapping(address => uint256) public tokenDecimal;
    address public ethPriceFeed;
    address public owner;
    string constant PREFIX = "\x19Ethereum Signed Message:\n32";

    // === ADMIN CONFIGURATION VARIABLES ===
    uint8 public maxUnifiedIdLength;
    uint8 public minUnifiedIdLength;
    mapping(address => bool) public adminUsers;

    // === ADMIN EVENTS ===
    event UnifiedIdLengthLimitsUpdated(uint8 minLength, uint8 maxLength);
    event AdminUserUpdated(address user, bool isAdmin);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Events
    event TokenPriceFeedSet(address indexed token, address indexed priceFeed);
    event EthPriceFeedSet(address indexed priceFeed);


    constructor() {
        owner = msg.sender;
        adminUsers[msg.sender] = true;
        maxUnifiedIdLength = 16;
        minUnifiedIdLength = 4;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier onlyAdmin() {
        require(adminUsers[msg.sender] || msg.sender == owner, "Caller not admin or owner");
        _;
    }

    function setTokenPriceFeed(address token, address priceFeed, uint decimal) external onlyOwner {
        tokenPriceFeed[token] = priceFeed;
        tokenDecimal[token] = decimal;
        emit TokenPriceFeedSet(token, priceFeed);
    }

    // Set the ETH price feed address
    function setEthPriceFeed(address _ethPriceFeed) external onlyOwner {
        ethPriceFeed = _ethPriceFeed;
        emit EthPriceFeedSet(_ethPriceFeed);
    }

    // Get the required token amount based on the registrar fees
    function getRequiredTokenAmount(address token, uint256 registrarFees) external view returns (uint256) {
        if (token == address(0)) {
            return registrarFees;
        } else {
            uint256[] memory tokenInfo = getTokenAmount(token);
            uint256[] memory result = new uint256[](5);
            result[0] = tokenInfo[0]; // tokenPriceInUSD
            result[1] = tokenInfo[1]; // decimals
            result[2] = tokenInfo[2]; // ethPriceInUSD
            result[3] = tokenInfo[3]; // ethDecimals

            uint256 decimalAdjustment = 0;
            if (tokenInfo[1] != tokenInfo[3]) {
                if (tokenInfo[1] > tokenInfo[3]) {
                    decimalAdjustment = tokenInfo[1] - tokenInfo[3];
                    result[4] = (registrarFees * tokenInfo[2] * (10 ** decimalAdjustment)) / tokenInfo[0];
                } else {
                    decimalAdjustment = tokenInfo[3] - tokenInfo[1];
                    result[4] = (registrarFees * tokenInfo[2]) / (tokenInfo[0] * (10 ** decimalAdjustment));
                }
            } else {
                result[4] = (registrarFees * tokenInfo[2]) / tokenInfo[0];
            }

            return result[4] / 10 ** tokenDecimal[token];
        }
    }

    // Get token amount and price information
    function getTokenAmount(address token) public view returns (uint256[] memory) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(tokenPriceFeed[token]);
        (
            ,
            int answer,
            ,
            ,
        ) = priceFeed.latestRoundData();
        require(answer > 0, "Invalid token price");
        uint256 tokenPriceInUSD = uint256(answer);
        uint8 decimals = priceFeed.decimals();

        AggregatorV3Interface ethPriceAggregator = AggregatorV3Interface(ethPriceFeed);
        (
            ,
            int ethAnswer,
            ,
            ,
        ) = ethPriceAggregator.latestRoundData();
        require(ethAnswer > 0, "Invalid ETH price");
        uint256 ethPriceInUSD = uint256(ethAnswer);
        uint8 ethDecimals = ethPriceAggregator.decimals();

        uint256[] memory result = new uint256[](4);
        result[0] = tokenPriceInUSD;
        result[1] = decimals;
        result[2] = ethPriceInUSD;
        result[3] = ethDecimals;

        return result;
    }

    function getMessageHash(bytes memory _data) public pure returns (bytes32) {
        return keccak256(_data);
    }

    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(PREFIX, _messageHash));
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) public pure returns (address) {
        require(_signature.length == 65, "Invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }
        if (v < 27) {
            v += 27;
        }
        require(v == 27 || v == 28, "Invalid signature 'v' value");
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function verifySignature(
        bytes memory _data,
        address _expectedSigner,
        bytes memory _signature
    ) public pure returns (bool) {
        bytes32 messageHash = getMessageHash(_data);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        address signer = recoverSigner(ethSignedMessageHash, _signature);
        return signer == _expectedSigner;
    }
    uint8 constant MAX_UNIFIED_ID_LENGTH = 16;
    uint8 constant MIN_UNIFIED_ID_LENGTH = 4;

    /**
    * @dev  check if address is of wallet or contract
    * @param _resolverAddress address to check
    */
    function isContract(address _resolverAddress)
    public view
    returns(bool)
    {
        uint32 size;
        assembly {
            size := extcodesize(_resolverAddress)
        }
        return (size > 0);
    }

    /**
    * @dev  convert a string to lower case
    * @param str string to be converted
    */

    function toLower(string memory str) public pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character...
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                // So we add 32 to make it lowercase
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }


    /**
    * @dev  to check length of a string
    * @param _name string length to be check
    */
    function checkLength(string memory _name) public pure returns (uint8){
        require(bytes(_name).length != 0, "Library : String passed is of zero length");
        return uint8(bytes(_name).length);
    }

    /**
    * @dev  to check if string contains alphanumeric or ASCII characters
    * @param unifiedId string to be checked
    */

    function checkAlphaNumericAndAscii(string memory unifiedId) public pure returns (bool) {
        bytes memory b = bytes(unifiedId);

        for(uint i; i < b.length; i++) {
            bytes1 char = b[i];

            if(!(
                (char >= 0x30 && char <= 0x39) || // 0-9
                (char >= 0x61 && char <= 0x7A) || // a-z
                (char >= 0x41 && char <= 0x5A) || // A-Z
                (uint8(char) >= 32 && uint8(char) <= 126) // ASCII printable characters
            )) {
                return false;
            }
        }

        return true;
    }

    function unifiedIdValid(string memory _registrarName) public view returns (bool) {
        string memory nameInLowerCase = toLower(_registrarName);
        uint8 length = checkLength(_registrarName);
        require(checkAlphaNumericAndAscii(nameInLowerCase), "only alphanumeric allowed");
        require(length <= maxUnifiedIdLength && length >= minUnifiedIdLength, "Unified Id length out of bounds");
        return true;
    }

    /**
     * @notice Check if unified ID is valid (alias for backward compatibility)
     * @param _unifiedId unified ID to validate
     * @return True if valid
     */
    function isUnifiedIdValid(string memory _unifiedId) public view returns (bool) {
        return unifiedIdValid(_unifiedId);
    }

    // === ADMIN FUNCTIONS ===

    /**
     * @notice Set UnifiedId length limits
     * @param _minLength Minimum length for unifiedId
     * @param _maxLength Maximum length for unifiedId
     */
    function setUnifiedIdLengthLimits(uint8 _minLength, uint8 _maxLength) external onlyOwner {
        require(_minLength > 0 && _maxLength > _minLength, "Invalid length limits");
        minUnifiedIdLength = _minLength;
        maxUnifiedIdLength = _maxLength;
        emit UnifiedIdLengthLimitsUpdated(_minLength, _maxLength);
    }

    /**
     * @notice Add or remove admin user
     * @param _user Address to modify admin status
     * @param _isAdmin True to grant admin rights, false to revoke
     */
    function setAdminUser(address _user, bool _isAdmin) external onlyOwner {
        require(_user != address(0), "User cannot be zero address");
        adminUsers[_user] = _isAdmin;
        emit AdminUserUpdated(_user, _isAdmin);
    }

    /**
     * @notice Transfer ownership of the contract
     * @param _newOwner Address of the new owner
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
        adminUsers[_newOwner] = true;
    }


    function getConfiguration() external view returns (
        uint8 _minUnifiedIdLength,
        uint8 _maxUnifiedIdIdLength,
        address _owner
    ) {
        return (
            minUnifiedIdLength,
            maxUnifiedIdLength,
            owner
        );
    }
}
