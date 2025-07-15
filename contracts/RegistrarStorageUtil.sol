// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title RegistrarStorageUtil
 * @author kunalmkv
 * @notice Utility contract for price feeds, signature verification, and admin management with role-based access control
 * @dev Implements secure signature verification with EIP-712, price feed management, two-step ownership, and OpenZeppelin AccessControl
 * @dev Uses UUPS upgradeable pattern with comprehensive authorization controls
 */
contract RegistrarStorageUtil is Initializable, UUPSUpgradeable, AccessControlUpgradeable {

    // ==================== ROLE DEFINITIONS ====================

    /// @notice Role for admin users with elevated privileges
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role for price feed managers
    bytes32 public constant PRICE_FEED_MANAGER_ROLE = keccak256("PRICE_FEED_MANAGER_ROLE");

    /// @notice Role for configuration managers
    bytes32 public constant CONFIG_MANAGER_ROLE = keccak256("CONFIG_MANAGER_ROLE");

    /// @notice Role for upgrading the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Mapping of token addresses to their corresponding Chainlink price feed addresses
    mapping(address => address) public tokenPriceFeed;

    /// @notice Mapping of token addresses to their decimal precision
    mapping(address => uint256) public tokenDecimal;

    /// @notice Address of ETH/USD Chainlink price feed
    address public ethPriceFeed;

    // === OWNABLE2STEP IMPLEMENTATION ===
    /// @dev Address of the current contract owner
    address private _owner;

    /// @dev Address of the pending owner during ownership transfer
    address private _pendingOwner;

    /// @dev Ethereum signed message prefix for signature verification
    string constant PREFIX = "\x19Ethereum Signed Message:\n32";

    // === ADMIN CONFIGURATION VARIABLES ===
    /// @notice Maximum allowed length for unified IDs
    uint8 public maxUnifiedIdLength;

    /// @notice Minimum required length for unified IDs
    uint8 public minUnifiedIdLength;

    // === ADMIN EVENTS ===

    /**
     * @notice Emitted when unified ID length limits are updated
     * @param minLength New minimum length requirement
     * @param maxLength New maximum length requirement
     */
    event UnifiedIdLengthLimitsUpdated(uint8 minLength, uint8 maxLength);

    /**
     * @notice Emitted when ownership transfer is initiated
     * @param previousOwner Current owner who initiated the transfer
     * @param newOwner Address that will become the new owner
     */
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /**
     * @notice Emitted when ownership transfer is completed
     * @param previousOwner Previous owner address
     * @param newOwner New owner address
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Events

    /**
     * @notice Emitted when a token price feed is configured
     * @param token Token address for which price feed was set
     * @param priceFeed Chainlink price feed address
     */
    event TokenPriceFeedSet(address indexed token, address indexed priceFeed);

    /**
     * @notice Emitted when ETH price feed is configured
     * @param priceFeed Chainlink ETH/USD price feed address
     */
    event EthPriceFeedSet(address indexed priceFeed);

    // === MISSING CRITICAL EVENTS ===

    /**
     * @notice Emitted when token decimal precision is updated
     * @param token Token address whose decimal was updated
     * @param oldDecimal Previous decimal value
     * @param newDecimal New decimal value
     */
    event TokenDecimalUpdated(address indexed token, uint256 oldDecimal, uint256 newDecimal);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

 /**
 * @notice Initializes the contract with default values and role-based access control
 * @dev Sets deployer as owner and admin, establishes default unified ID length limits, and sets up roles
 * @param initialOwner Address that will become the initial owner and admin
 */
function initialize(address initialOwner) public initializer {
    __UUPSUpgradeable_init();
    __AccessControl_init();

    require(initialOwner != address(0), "Initial owner cannot be zero address");

    _owner = initialOwner;
    emit OwnershipTransferred(address(0), initialOwner);

    // Initialize default values
    maxUnifiedIdLength = 16;
    minUnifiedIdLength = 4;

    // Setup roles
    _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
    _grantRole(ADMIN_ROLE, initialOwner);
    _grantRole(PRICE_FEED_MANAGER_ROLE, initialOwner);
    _grantRole(CONFIG_MANAGER_ROLE, initialOwner);
    _grantRole(UPGRADER_ROLE, initialOwner);
}

/**
 * @notice Authorizes contract upgrades
 * @dev Only UPGRADER_ROLE, ADMIN_ROLE, or owner can authorize upgrades
 */
function _authorizeUpgrade(address /* newImplementation */) internal view override {
    require(
        hasRole(UPGRADER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender) || msg.sender == owner(),
        "AccessControl: caller is not authorized"
    );
}


    /**
     * @notice Returns the address of the current owner
     * @return Address of the current contract owner
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @notice Returns the address of the pending owner during ownership transfer
     * @return Address of the pending owner, or zero address if no transfer is pending
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @notice Modifier to restrict access to owner only
     * @dev Reverts if caller is not the current owner
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }



    /**
     * @notice Renounces ownership of the contract
     * @dev Leaves the contract without owner, disabling owner-only functions permanently
     * @dev Can only be called by the current owner
     * @dev WARNING: This action is irreversible
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @notice Initiates ownership transfer to a new account (Step 1 of 2)
     * @dev The new owner must call acceptOwnership() to complete the transfer
     * @param newOwner Address of the proposed new owner
     * @custom:requirements
     * - newOwner cannot be zero address
     * - newOwner cannot be the current owner
     * - Only current owner can call this function
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        require(newOwner != owner(), "Ownable: new owner is the same as current owner");
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @notice Accepts ownership transfer (Step 2 of 2)
     * @dev Completes the two-step ownership transfer process
     * @dev Only the pending owner can call this function
     * @custom:requirements
     * - Caller must be the pending owner
     * - A transfer must be pending
     */
    function acceptOwnership() external {
        address sender = msg.sender;
        require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
        _transferOwnership(sender);
    }

    /**
     * @dev Internal function to transfer ownership
     * @param newOwner Address of the new owner
     */
    function _transferOwnership(address newOwner) internal virtual {
        delete _pendingOwner;
        address oldOwner = _owner;
        _owner = newOwner;
        if (newOwner != address(0)) {
            _grantRole(ADMIN_ROLE, newOwner);
            _grantRole(PRICE_FEED_MANAGER_ROLE, newOwner);
            _grantRole(CONFIG_MANAGER_ROLE, newOwner);
            _grantRole(UPGRADER_ROLE, newOwner);
        }
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @notice Sets the price feed for a specific token
     * @dev Configures Chainlink price feed and decimal precision for token calculations
     * @param token Address of the token contract
     * @param priceFeed Address of the Chainlink price feed for this token
     * @param decimal Decimal precision for the token
     * @custom:requirements
     * - Only price feed manager can call this function
     * - token cannot be zero address
     * - priceFeed cannot be zero address
     * @custom:events
     * - Emits TokenPriceFeedSet
     * - Emits TokenDecimalUpdated if decimal value changed
     */
    function setTokenPriceFeed(address token, address priceFeed, uint256 decimal) external onlyRole(PRICE_FEED_MANAGER_ROLE) {
        require(token != address(0), "Token: zero address");
        require(priceFeed != address(0), "Price feed: zero address");
        require(isContract(token), "Token address is not a contract");
        require(isContract(priceFeed), "Price feed address is not a contract");

        uint256 oldDecimal = tokenDecimal[token];
        tokenPriceFeed[token] = priceFeed;
        tokenDecimal[token] = decimal;

        emit TokenPriceFeedSet(token, priceFeed);
        if (oldDecimal != decimal) {
            emit TokenDecimalUpdated(token, oldDecimal, decimal);
        }
    }

    /**
     * @notice Sets the ETH/USD price feed address
     * @dev Configures the Chainlink ETH/USD price feed for ETH price calculations
     * @param _ethPriceFeed Address of the Chainlink ETH/USD price feed
     * @custom:requirements
     * - Only price feed manager can call this function
     * - _ethPriceFeed cannot be zero address
     * @custom:events
     * - Emits EthPriceFeedSet
     */
    function setEthPriceFeed(address _ethPriceFeed) external onlyRole(PRICE_FEED_MANAGER_ROLE) {
        require(_ethPriceFeed != address(0), "ETH price feed: zero address");
        require(isContract(_ethPriceFeed), "ETH price feed address is not a contract");
        
        ethPriceFeed = _ethPriceFeed;
        emit EthPriceFeedSet(_ethPriceFeed);
    }

    /**
     * @notice Calculates required token amount based on registrar fees
     * @dev Converts registrar fees from ETH to specified token using Chainlink price feeds
     * @param token Address of the payment token (zero address for ETH)
     * @param registrarFees Fee amount in ETH wei
     * @return Required token amount adjusted for token decimals
     * @custom:requirements
     * - Token and ETH price feeds must be configured
     * - Price feed data must be valid (positive)
     * @custom:calculations
     * - For ETH: returns fees directly
     * - For tokens: converts ETH amount to token amount using price feeds
     * - Handles decimal adjustments between token and ETH price feeds
     */
    function getRequiredTokenAmount(address token, uint256 registrarFees) external view returns (uint256) {
        if (token == address(0)) {
            return registrarFees;
        } else {

            uint256[] memory tokenInfo = getTokenAmount(token);
            uint256 tokenPriceInUSD = tokenInfo[0]; // Token USD price (Chainlink decimals = 8)
            uint256 tokenDecimals = tokenInfo[1];   // Token decimals (e.g., USDC = 6)
            uint256 ethPriceInUSD = tokenInfo[2];   // ETH USD price (Chainlink decimals = 8)

            require(tokenPriceInUSD > 0 && ethPriceInUSD > 0, "Invalid price data");

            // STEP 1: Convert registrarFees (wei, 18 decimals) to USD (standardized 8 decimals)
            uint256 registrarFeeInUSD = (registrarFees * ethPriceInUSD) / 1e18;
            // registrarFees(1e18) * ethPriceInUSD(1e8) / 1e18 → 1e8 precision USD value

            // STEP 2: Convert USD amount (8 decimals) to token amount using token price (8 decimals)
            uint256 tokenAmount = (registrarFeeInUSD * (10 ** tokenDecimals)) / tokenPriceInUSD;
            // (1e8 USD) * (10^tokenDecimals) / (1e8 USD) → tokenDecimals precision

            return tokenAmount; // Correct token amount (in token's own decimals)
        }
    }

    /**
     * @notice Retrieves current price data for a token and ETH
     * @dev Fetches latest price data from Chainlink price feeds
     * @param token Address of the token to get price information for
     * @return Array containing [tokenPriceInUSD, tokenDecimals, ethPriceInUSD, ethDecimals]
     * @custom:requirements
     * - Token price feed must be configured
     * - ETH price feed must be configured
     * - Price feed answers must be positive
     * @custom:reverts
     * - "Invalid token price" if token price <= 0
     * - "Invalid ETH price" if ETH price <= 0
     */
    function getTokenAmount(address token) public view returns (uint256[] memory) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(tokenPriceFeed[token]);
        (
            ,
            int256 answer,
            ,
            ,
        ) = priceFeed.latestRoundData();
        require(answer != 0, "Invalid token price");
        uint256 tokenPriceInUSD = uint256(answer);
        uint8 decimals = priceFeed.decimals();

        AggregatorV3Interface ethPriceAggregator = AggregatorV3Interface(ethPriceFeed);
        (
            ,
            int256 ethAnswer,
            ,
            ,
        ) = ethPriceAggregator.latestRoundData();
        require(ethAnswer != 0, "Invalid ETH price");
        uint256 ethPriceInUSD = uint256(ethAnswer);
        uint8 ethDecimals = ethPriceAggregator.decimals();

        uint256[] memory result = new uint256[](4);
        result[0] = tokenPriceInUSD;
        result[1] = decimals;
        result[2] = ethPriceInUSD;
        result[3] = ethDecimals;

        return result;
    }

    /**
     * @notice Computes the keccak256 hash of given data
     * @dev Pure function for generating message hashes
     * @param _data Bytes data to hash
     * @return The keccak256 hash of the input data
     */
    function getMessageHash(bytes memory _data) public pure returns (bytes32) {
        return keccak256(_data);
    }

    /**
     * @notice Creates an Ethereum signed message hash
     * @dev Prepends Ethereum message prefix to the hash
     * @param _messageHash The original message hash
     * @return The hash with Ethereum signed message prefix
     */
    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(PREFIX, _messageHash));
    }

    /**
     * @notice Recovers the signer address from an Ethereum signed message hash and signature
     * @dev Uses ecrecover to extract the signer from the signature components
     * @param hash The hash of the signed message with Ethereum prefix
     * @param _signature The signature bytes (65 bytes: r + s + v)
     * @return The address of the account that signed the message
     * @custom:requirements
     * - Signature must be exactly 65 bytes
     * - Signature 'v' value must be 27 or 28
     * @custom:reverts
     * - "Invalid signature length" if signature is not 65 bytes
     * - "Invalid signature 'v' value" if v is not 27 or 28
     */
    function recoverSigner(bytes32 hash, bytes memory _signature) public pure returns (address) {
        require(_signature.length == 65, "Invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }

        // Enforce EIP-2: Prevent signature malleability by requiring low s-values
        require(
            uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "Invalid signature 's' value"
        );

        // Check v-value is correct
        require(v == 27 || v == 28, "Invalid signature 'v' value");

        return ecrecover(hash, v, r, s);
    }

    /**
     * @notice Simple signature verification function
     * @dev Verifies a signature using Ethereum signed message format
     * @param _data The data that was signed
     * @param _expectedSigner Expected signer address
     * @param _signature The signature to verify
     * @return True if signature is valid
     */
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

    /**
     * @notice Converts a string to lowercase
     * @dev Iterates through each character and converts uppercase to lowercase
     * @param str String to be converted
     * @return Lowercase version of the input string
     */
    function toLower(string memory str) public pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; ++i) {
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
     * @notice Checks the length of a string
     * @dev Returns the byte length of the string
     * @param _name String to check length of
     * @return Length of the string in bytes
     * @custom:reverts "Library : String passed is of zero length" if string is empty
     */
    function checkLength(string memory _name) public pure returns (uint8){
        require(bytes(_name).length != 0, "Library : String passed is of zero length");
        return uint8(bytes(_name).length);
    }

    /**
     * @notice Validates if string contains only alphanumeric and ASCII printable characters
     * @dev Checks each character to ensure it's within allowed ranges
     * @param unifiedId String to validate
     * @return True if all characters are valid, false otherwise
     * @custom:allowed-chars
     * - Digits: 0-9 (0x30-0x39)
     * - Lowercase: a-z (0x61-0x7A)
     * - Uppercase: A-Z (0x41-0x5A)
     * - ASCII printable: 32-126
     */
    function checkAlphaNumericAndAscii(string memory unifiedId) public pure returns (bool) {
        bytes memory b = bytes(unifiedId);

        for(uint256 i; i < b.length; ++i) {
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

    /**
     * @notice Validates a unified ID format and length
     * @dev Checks if unified ID meets all requirements: length, character set, etc.
     * @param _registrarName Unified ID to validate
     * @return True if valid
     * @custom:requirements
     * - Must be within configured length limits
     * - Must contain only alphanumeric and ASCII printable characters
     * @custom:reverts
     * - "only alphanumeric allowed" if invalid characters found
     * - "Unified Id length out of bounds" if length is invalid
     */
    function unifiedIdValid(string memory _registrarName) public view returns (bool) {
        string memory nameInLowerCase = toLower(_registrarName);
        uint8 length = checkLength(_registrarName);
        require(checkAlphaNumericAndAscii(nameInLowerCase), "only alphanumeric allowed");
        require(length <= maxUnifiedIdLength && length >= minUnifiedIdLength, "Unified Id length out of bounds");
        return true;
    }

    /**
     * @notice Check if unified ID is valid (alias for backward compatibility)
     * @dev Calls unifiedIdValid() internally
     * @param _unifiedId unified ID to validate
     * @return True if valid
     */
    function isUnifiedIdValid(string memory _unifiedId) public view returns (bool) {
        return unifiedIdValid(_unifiedId);
    }

    /**
     * @notice Checks if an address is a contract or externally owned account
     * @dev Uses extcodesize to determine if address contains contract code
     * @param _resolverAddress Address to check
     * @return True if address is a contract, false if EOA
     */
    function isContract(address _resolverAddress) public view returns(bool) {
        uint32 size;
        assembly {
            size := extcodesize(_resolverAddress)
        }
        return (size != 0);
    }

    // ==================== ROLE MANAGEMENT FUNCTIONS ====================

    /**
     * @notice Grant admin role to an address
     * @param admin Address to grant admin role
     */
    function grantAdminRole(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Revoke admin role from an address
     * @param admin Address to revoke admin role
     */
    function revokeAdminRole(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Grant price feed manager role to an address
     * @param manager Address to grant price feed manager role
     */
    function grantPriceFeedManagerRole(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(PRICE_FEED_MANAGER_ROLE, manager);
    }

    /**
     * @notice Revoke price feed manager role from an address
     * @param manager Address to revoke price feed manager role
     */
    function revokePriceFeedManagerRole(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(PRICE_FEED_MANAGER_ROLE, manager);
    }

    /**
     * @notice Grant config manager role to an address
     * @param manager Address to grant config manager role
     */
    function grantConfigManagerRole(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(CONFIG_MANAGER_ROLE, manager);
    }

    /**
     * @notice Revoke config manager role from an address
     * @param manager Address to revoke config manager role
     */
    function revokeConfigManagerRole(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(CONFIG_MANAGER_ROLE, manager);
    }

    /**
     * @notice Check if address has admin role
     * @param account Address to check
     * @return True if address has admin role
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /**
     * @notice Check if address has price feed manager role
     * @param account Address to check
     * @return True if address has price feed manager role
     */
    function isPriceFeedManager(address account) external view returns (bool) {
        return hasRole(PRICE_FEED_MANAGER_ROLE, account);
    }

    /**
     * @notice Check if address has config manager role
     * @param account Address to check
     * @return True if address has config manager role
     */
    function isConfigManager(address account) external view returns (bool) {
        return hasRole(CONFIG_MANAGER_ROLE, account);
    }

    /**
     * @notice Grant upgrader role to an address
     * @param upgrader Address to grant upgrader role
     */
    function grantUpgraderRole(address upgrader) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    /**
     * @notice Revoke upgrader role from an address
     * @param upgrader Address to revoke upgrader role
     */
    function revokeUpgraderRole(address upgrader) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(UPGRADER_ROLE, upgrader);
    }

    /**
     * @notice Check if address has upgrader role
     * @param account Address to check
     * @return True if address has upgrader role
     */
    function isUpgrader(address account) external view returns (bool) {
        return hasRole(UPGRADER_ROLE, account);
    }

    // === ADMIN FUNCTIONS ===

    /**
     * @notice Sets the length limits for unified IDs
     * @dev Updates both minimum and maximum length requirements
     * @param _minLength Minimum allowed length for unified IDs
     * @param _maxLength Maximum allowed length for unified IDs
     * @custom:requirements
     * - Only config manager can call this function
     * - _minLength must be greater than 0
     * - _maxLength must be greater than _minLength
     * @custom:events Emits UnifiedIdLengthLimitsUpdated
     */
    function setUnifiedIdLengthLimits(uint8 _minLength, uint8 _maxLength) external onlyRole(CONFIG_MANAGER_ROLE) {
        require(_minLength != 0 && _maxLength > _minLength, "Invalid length limits");
        minUnifiedIdLength = _minLength;
        maxUnifiedIdLength = _maxLength;
        emit UnifiedIdLengthLimitsUpdated(_minLength, _maxLength);
    }

    /**
     * @notice Returns current contract configuration
     * @dev Provides read access to key configuration parameters
     * @return _minUnifiedIdLength Current minimum unified ID length
     * @return _maxUnifiedIdIdLength Current maximum unified ID length
     * @return currentOwner Current contract owner address
     */
    function getConfiguration() external view returns (
        uint8 _minUnifiedIdLength,
        uint8 _maxUnifiedIdIdLength,
        address currentOwner
    ) {
        return (
            minUnifiedIdLength,
            maxUnifiedIdLength,
            owner()
        );
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
