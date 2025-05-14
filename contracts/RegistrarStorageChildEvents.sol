// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./RegistrarStorageUtil.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract RegistrarStorageChildEvents is UUPSUpgradeable, OwnableUpgradeable {
    struct UserData {
        address primary;
        mapping(address => bool) isSecondary;
        address[] secondaries;
        bool exists;
    }
    struct Registrar {
        bool isRegisteredRegistrar;
        string registrarName;
        address registrarAddress;
    }

    address public contractOwner;
    address payable public walletAddress;
    uint256 public MAX_NAME_UPDATES;
    bool public isPaused;
    uint256 public totalRegistrars;
    uint256 public totalUnifiedIdRegistered;
    RegistrarStorageUtil public util;
    address public relayer;
    mapping(address => bool) public authorizedRelayers;

    mapping(address => bool) public isRegisteredRegistrar;
    mapping(address => string) public registrarNames;
    mapping(string => address) public registrarNameToAddress;
    mapping(address => uint8) public totalRegistrarUpdates;
    mapping(address => bytes[]) public resolveOldRegistrarAddress;
    mapping(address => Registrar) public Registrars;

    mapping(string => UserData) private userAddresses;
    mapping(string => bool) public unavailableUnifiedIds;
    string[] public registeredUnifiedIds;

    mapping(string => address) public resolveAddressFromUnifiedId;
    mapping(address => bool) public isAddressTaken;
    mapping(address => string) public resolveUnifiedIdfromAddress;

    event SecondaryAddressAdded(string unifiedId, address secondary);
    event SecondaryAddressRemoved(string unifiedId, address secondary);
    event RegistrarRegistered(address registrar, string registrarName);
    event RegistrarUpdated(address registrar, string oldName, string newName);
    event RegistrationPaused(address by);
    event RegistrationUnpaused(address by);
    event UnifiedIDRegistered(string unifiedId, address primary);
    event UnifiedIDUpdated(string unifiedId, address oldPrimary, address newPrimary);
    event TokenAllowed(address token);
    event TokenDisallowed(address token);
    event UnifiedIDChanged(string oldUnifiedId, string newUnifiedId, address primary);
    event RegisterUnifiedIdInitiated(
        string unifiedId,
        address primaryAddress,
        bytes masterSignature,
        bytes primarySignature,
        bytes options
    );
    event UpdateUnifiedIdInitiated(string oldUnifiedId, string newUnifiedId, bytes signature, bytes options);
    event UpdateUnifiedIdPrimaryAddressInitiated(
        string unifiedId,
        address newPrimaryAddress,
        bytes currentPrimarySignature,
        bytes newPrimarySignature,
        bytes options
    );
    event AddSecondaryAddressInitiated(
        string unifiedId,
        address secondaryAddress,
        bytes primarySignature,
        bytes secondarySignature,
        bytes options
    );
    event RemoveSecondaryAddressInitiated(string unifiedId, address secondaryAddress, bytes signature, bytes options);

    modifier unifiedIdExists(string calldata _unifiedId) {
        require(userAddresses[_unifiedId].exists, "UnifiedID does not exist");
        _;
    }
    modifier WhenNotPaused() {
        require(!isPaused, "Contract is Paused");
        _;
    }
    modifier unifiedIdDoesNotExist(string calldata _unifiedId) {
        require(!userAddresses[_unifiedId].exists, "UnifiedID already exists");
        require(!unavailableUnifiedIds[_unifiedId], "UnifiedID not available");
        _;
    }
    modifier registrarChecks(string memory _registrarName) {
        bytes memory regNameBytes = bytes(_registrarName);
        require(registrarNameToAddress[string(regNameBytes)] == address(0x0), "Registrar name is already taken.");
        require(
            resolveAddressFromUnifiedId[_registrarName] == address(0x0),
            "This Registrar name is already registered as a UnifiedID."
        );
        _;
    }
    modifier onlyRegistrar() {
        require(isRegisteredRegistrar[msg.sender], "Caller not a registrar");
        _;
    }
    modifier onlyAuthorizedRelayer() {
        require(authorizedRelayers[msg.sender], "Caller not authorized relayer");
        _;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize(address _RegistrarStorageUtil) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        MAX_NAME_UPDATES = 3;
        util = RegistrarStorageUtil(_RegistrarStorageUtil);
    }

    function setUtilImplementation(address _RegistrarStorageUtil) external onlyOwner {
        util = RegistrarStorageUtil(_RegistrarStorageUtil);
    }

    function setAuthorizedRelayer(address _relayer, bool authorized) external onlyOwner {
        authorizedRelayers[_relayer] = authorized;
    }

    function registerRegistrar(
        string calldata _registrarName,
        address _registrarAddress
    ) external payable WhenNotPaused registrarChecks(_registrarName) onlyOwner returns (bool) {
        require(!isAddressTaken[_registrarAddress], "This address is already registered.");
        Registrars[_registrarAddress] = Registrar({
            isRegisteredRegistrar: true,
            registrarName: _registrarName,
            registrarAddress: _registrarAddress
        });
        registrarNameToAddress[_registrarName] = _registrarAddress;
        registrarNames[_registrarAddress] = _registrarName;
        isRegisteredRegistrar[_registrarAddress] = true;
        isAddressTaken[_registrarAddress] = true;
        totalRegistrars++;
        emit RegistrarRegistered(_registrarAddress, _registrarName);
        return true;
    }

    function updateRegistrar(
        address _registrar,
        string calldata _newRegistrarName
    ) external WhenNotPaused registrarChecks(_newRegistrarName) onlyOwner returns (bool) {
        require(isAddressTaken[_registrar], "Registrar should register first.");
        require(totalRegistrarUpdates[_registrar] + 1 <= MAX_NAME_UPDATES, "Maximum update count reached.");
        Registrar storage registrarObject = Registrars[_registrar];
        string memory oldName = registrarObject.registrarName;
        registrarNameToAddress[oldName] = address(0x0);
        resolveOldRegistrarAddress[_registrar].push(bytes(registrarObject.registrarName));
        registrarNames[_registrar] = _newRegistrarName;
        registrarObject.registrarName = _newRegistrarName;
        registrarNameToAddress[_newRegistrarName] = _registrar;
        totalRegistrarUpdates[_registrar]++;
        emit RegistrarUpdated(_registrar, oldName, _newRegistrarName);
        return true;
    }

    function PauseRegistration() external onlyOwner {
        isPaused = true;
        emit RegistrationPaused(msg.sender);
    }

    function unPauseRegistration() external onlyOwner {
        isPaused = false;
        emit RegistrationUnpaused(msg.sender);
    }

    function initiateRegisterUnifiedId(
        string calldata _unifiedId,
        address _primaryAddress,
        bytes calldata _masterSignature,
        bytes calldata _primarySignature,
        bytes calldata _options
    ) external payable WhenNotPaused onlyRegistrar returns (bool) {
        require(util.isSafleIdValid(_unifiedId), "Invalid UnifiedId format");
        require(!userAddresses[_unifiedId].exists, "UnifiedID already exists");
        require(!unavailableUnifiedIds[_unifiedId], "UnifiedID not available");
        require(registrarNameToAddress[_unifiedId] == address(0x0), "This UnifiedId is taken by a Registrar.");
        require(resolveAddressFromUnifiedId[_unifiedId] == address(0x0), "This UnifiedId is already registered.");
        emit RegisterUnifiedIdInitiated(_unifiedId, _primaryAddress, _masterSignature, _primarySignature, _options);
        return true;
    }

    function completeRegisterUnifiedId(
        string calldata _unifiedId,
        address _primaryAddress
    ) external onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];
        userData.primary = _primaryAddress;
        userData.exists = true;
        resolveAddressFromUnifiedId[_unifiedId] = _primaryAddress;
        resolveUnifiedIdfromAddress[_primaryAddress] = _unifiedId;
        registeredUnifiedIds.push(_unifiedId);
        unavailableUnifiedIds[_unifiedId] = true;
        totalUnifiedIdRegistered++;
        emit UnifiedIDRegistered(_unifiedId, _primaryAddress);
        return true;
    }

    function initiateUpdateUnifiedId(
        string calldata _oldUnifiedId,
        string calldata _newUnifiedId,
        bytes calldata _signature,
        bytes calldata _options
    )
        external
        payable
        WhenNotPaused
        unifiedIdExists(_oldUnifiedId)
        unifiedIdDoesNotExist(_newUnifiedId)
        onlyRegistrar
        returns (bool)
    {
        require(util.isSafleIdValid(_newUnifiedId), "Invalid new UnifiedId format");
        emit UpdateUnifiedIdInitiated(_oldUnifiedId, _newUnifiedId, _signature, _options);
        return true;
    }

    function completeUpdateUnifiedId(
        string memory _oldUnifiedId,
        string memory _newUnifiedId
    ) external onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_oldUnifiedId];
        resolveAddressFromUnifiedId[_newUnifiedId] = userData.primary;
        resolveAddressFromUnifiedId[_oldUnifiedId] = address(0);
        resolveUnifiedIdfromAddress[userData.primary] = _newUnifiedId;

        UserData storage newUserData = userAddresses[_newUnifiedId];
        newUserData.primary = userData.primary;
        newUserData.exists = true;

        for (uint i = 0; i < userData.secondaries.length; i++) {
            address secondaryAddr = userData.secondaries[i];
            newUserData.isSecondary[secondaryAddr] = true;
            newUserData.secondaries.push(secondaryAddr);
        }

        for (uint i = 0; i < registeredUnifiedIds.length; i++) {
            if (keccak256(bytes(registeredUnifiedIds[i])) == keccak256(bytes(_oldUnifiedId))) {
                registeredUnifiedIds[i] = _newUnifiedId;
                break;
            }
        }

        unavailableUnifiedIds[_oldUnifiedId] = true;
        unavailableUnifiedIds[_newUnifiedId] = true;
        delete userAddresses[_oldUnifiedId];
        emit UnifiedIDChanged(_oldUnifiedId, _newUnifiedId, userData.primary);
        return true;
    }

    function initiateUpdateUnifiedIdPrimaryAddress(
        string calldata _unifiedId,
        address _newPrimaryAddress,
        bytes calldata currentPrimarySignature,
        bytes calldata newPrimarySignature,
        bytes calldata _options
    ) external payable WhenNotPaused unifiedIdExists(_unifiedId) onlyRegistrar returns (bool) {
        emit UpdateUnifiedIdPrimaryAddressInitiated(
            _unifiedId,
            _newPrimaryAddress,
            currentPrimarySignature,
            newPrimarySignature,
            _options
        );
        return true;
    }

    function completeUpdateUnifiedIdPrimaryAddress(
        string calldata _unifiedId,
        address _newPrimaryAddress
    ) external onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];
        address oldPrimary = userData.primary;
        userData.primary = _newPrimaryAddress;
        resolveAddressFromUnifiedId[_unifiedId] = _newPrimaryAddress;
        resolveUnifiedIdfromAddress[_newPrimaryAddress] = _unifiedId;
        resolveUnifiedIdfromAddress[oldPrimary] = "";
        emit UnifiedIDUpdated(_unifiedId, oldPrimary, _newPrimaryAddress);
        return true;
    }

    function initiateAddSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress,
        bytes calldata _primarySignature,
        bytes calldata _secondarySignature,
        bytes calldata _options
    ) external payable WhenNotPaused unifiedIdExists(_unifiedId) onlyRegistrar returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];
        require(!userData.isSecondary[_secondaryAddress], "Secondary address already added");
        emit AddSecondaryAddressInitiated(
            _unifiedId,
            _secondaryAddress,
            _primarySignature,
            _secondarySignature,
            _options
        );
        return true;
    }

    function completeAddSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress
    ) external onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];
        userData.isSecondary[_secondaryAddress] = true;
        userData.secondaries.push(_secondaryAddress);
        emit SecondaryAddressAdded(_unifiedId, _secondaryAddress);
        return true;
    }

    function initiateRemoveSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress,
        bytes calldata _signature,
        bytes calldata _options
    ) external payable WhenNotPaused unifiedIdExists(_unifiedId) onlyRegistrar returns (bool) {
        emit RemoveSecondaryAddressInitiated(_unifiedId, _secondaryAddress, _signature, _options);
        return true;
    }

    function completeRemoveSecondaryAddress(
        string calldata _unifiedId,
        address _secondaryAddress
    ) external onlyAuthorizedRelayer returns (bool) {
        UserData storage userData = userAddresses[_unifiedId];
        userData.isSecondary[_secondaryAddress] = false;
        for (uint i = 0; i < userData.secondaries.length; i++) {
            if (userData.secondaries[i] == _secondaryAddress) {
                userData.secondaries[i] = userData.secondaries[userData.secondaries.length - 1];
                userData.secondaries.pop();
                break;
            }
        }
        emit SecondaryAddressRemoved(_unifiedId, _secondaryAddress);
        return true;
    }

    function isPrimaryAddress(string calldata _unifiedId, address _address) external view returns (bool) {
        return userAddresses[_unifiedId].primary == _address;
    }

    function isSecondaryAddress(string calldata _unifiedId, address _address) external view returns (bool) {
        return userAddresses[_unifiedId].isSecondary[_address];
    }

    function getPrimaryAddress(string calldata _unifiedId) external view returns (address) {
        return userAddresses[_unifiedId].primary;
    }

    function getSecondaryAddresses(string calldata _unifiedId) external view returns (address[] memory) {
        return userAddresses[_unifiedId].secondaries;
    }

    function getRegisteredUnifiedIds() external view returns (string[] memory) {
        return registeredUnifiedIds;
    }
}
