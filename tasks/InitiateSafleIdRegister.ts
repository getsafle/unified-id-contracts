import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { EndpointId } from '@layerzerolabs/lz-definitions'

const RegistrarStorageABI = [
    {
        inputs: [
            {
                internalType: 'address',
                name: 'target',
                type: 'address',
            },
        ],
        name: 'AddressEmptyCode',
        type: 'error',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_safleId',
                type: 'string',
            },
            {
                internalType: 'address',
                name: '_secondaryAddress',
                type: 'address',
            },
        ],
        name: 'completeAddSecondaryAddress',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_safleId',
                type: 'string',
            },
            {
                internalType: 'address',
                name: '_primaryAddress',
                type: 'address',
            },
        ],
        name: 'completeRegisterSafleId',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_safleId',
                type: 'string',
            },
            {
                internalType: 'address',
                name: '_secondaryAddress',
                type: 'address',
            },
        ],
        name: 'completeRemoveSecondaryAddress',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_oldSafleId',
                type: 'string',
            },
            {
                internalType: 'string',
                name: '_newSafleId',
                type: 'string',
            },
        ],
        name: 'completeUpdateSafleId',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_safleId',
                type: 'string',
            },
            {
                internalType: 'address',
                name: '_newPrimaryAddress',
                type: 'address',
            },
        ],
        name: 'completeUpdateSafleIdPrimaryAddress',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: 'implementation',
                type: 'address',
            },
        ],
        name: 'ERC1967InvalidImplementation',
        type: 'error',
    },
    {
        inputs: [],
        name: 'ERC1967NonPayable',
        type: 'error',
    },
    {
        inputs: [],
        name: 'FailedCall',
        type: 'error',
    },
    {
        inputs: [],
        name: 'InvalidInitialization',
        type: 'error',
    },
    {
        inputs: [],
        name: 'NotInitializing',
        type: 'error',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: 'owner',
                type: 'address',
            },
        ],
        name: 'OwnableInvalidOwner',
        type: 'error',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: 'account',
                type: 'address',
            },
        ],
        name: 'OwnableUnauthorizedAccount',
        type: 'error',
    },
    {
        inputs: [],
        name: 'UUPSUnauthorizedCallContext',
        type: 'error',
    },
    {
        inputs: [
            {
                internalType: 'bytes32',
                name: 'slot',
                type: 'bytes32',
            },
        ],
        name: 'UUPSUnsupportedProxiableUUID',
        type: 'error',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: 'string',
                name: 'safleId',
                type: 'string',
            },
            {
                indexed: false,
                internalType: 'address',
                name: 'secondaryAddress',
                type: 'address',
            },
            {
                indexed: false,
                internalType: 'bytes',
                name: 'primarySignature',
                type: 'bytes',
            },
            {
                indexed: false,
                internalType: 'bytes',
                name: 'secondarySignature',
                type: 'bytes',
            },
            {
                indexed: false,
                internalType: 'bytes',
                name: 'options',
                type: 'bytes',
            },
        ],
        name: 'AddSecondaryAddressInitiated',
        type: 'event',
    },
    {
        inputs: [
            {
                internalType: 'address payable',
                name: '_walletAddress',
                type: 'address',
            },
            {
                internalType: 'address',
                name: '_RegistrarStorageUtil',
                type: 'address',
            },
            {
                internalType: 'address',
                name: '_relayer',
                type: 'address',
            },
        ],
        name: 'initialize',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: 'uint64',
                name: 'version',
                type: 'uint64',
            },
        ],
        name: 'Initialized',
        type: 'event',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_safleId',
                type: 'string',
            },
            {
                internalType: 'address',
                name: '_secondaryAddress',
                type: 'address',
            },
            {
                internalType: 'bytes',
                name: '_primarySignature',
                type: 'bytes',
            },
            {
                internalType: 'bytes',
                name: '_secondarySignature',
                type: 'bytes',
            },
            {
                internalType: 'bytes',
                name: '_options',
                type: 'bytes',
            },
        ],
        name: 'initiateAddSecondaryAddress',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'payable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_safleId',
                type: 'string',
            },
            {
                internalType: 'address',
                name: '_primaryAddress',
                type: 'address',
            },
            {
                internalType: 'bytes',
                name: '_signature',
                type: 'bytes',
            },
            {
                internalType: 'address',
                name: '_token',
                type: 'address',
            },
            {
                internalType: 'bytes',
                name: '_options',
                type: 'bytes',
            },
        ],
        name: 'initiateRegisterSafleId',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'payable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_safleId',
                type: 'string',
            },
            {
                internalType: 'address',
                name: '_secondaryAddress',
                type: 'address',
            },
            {
                internalType: 'bytes',
                name: '_signature',
                type: 'bytes',
            },
            {
                internalType: 'bytes',
                name: '_options',
                type: 'bytes',
            },
        ],
        name: 'initiateRemoveSecondaryAddress',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'payable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_oldSafleId',
                type: 'string',
            },
            {
                internalType: 'string',
                name: '_newSafleId',
                type: 'string',
            },
            {
                internalType: 'bytes',
                name: '_signature',
                type: 'bytes',
            },
            {
                internalType: 'address',
                name: '_token',
                type: 'address',
            },
            {
                internalType: 'bytes',
                name: '_options',
                type: 'bytes',
            },
        ],
        name: 'initiateUpdateSafleId',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'payable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_safleId',
                type: 'string',
            },
            {
                internalType: 'address',
                name: '_newPrimaryAddress',
                type: 'address',
            },
            {
                internalType: 'bytes',
                name: '_signature',
                type: 'bytes',
            },
            {
                internalType: 'bytes',
                name: '_options',
                type: 'bytes',
            },
        ],
        name: 'initiateUpdateSafleIdPrimaryAddress',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'payable',
        type: 'function',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'address',
                name: 'previousOwner',
                type: 'address',
            },
            {
                indexed: true,
                internalType: 'address',
                name: 'newOwner',
                type: 'address',
            },
        ],
        name: 'OwnershipTransferred',
        type: 'event',
    },
    {
        inputs: [],
        name: 'PauseRegistration',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_registrarName',
                type: 'string',
            },
            {
                internalType: 'address',
                name: '_token',
                type: 'address',
            },
        ],
        name: 'registerRegistrar',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'payable',
        type: 'function',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: 'string',
                name: 'safleId',
                type: 'string',
            },
            {
                indexed: false,
                internalType: 'address',
                name: 'primaryAddress',
                type: 'address',
            },
            {
                indexed: false,
                internalType: 'bytes',
                name: 'signature',
                type: 'bytes',
            },
            {
                indexed: false,
                internalType: 'bytes',
                name: 'options',
                type: 'bytes',
            },
        ],
        name: 'RegisterSafleIdInitiated',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'address',
                name: 'registrar',
                type: 'address',
            },
            {
                indexed: false,
                internalType: 'string',
                name: 'registrarName',
                type: 'string',
            },
        ],
        name: 'RegistrarRegistered',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'address',
                name: 'registrar',
                type: 'address',
            },
            {
                indexed: false,
                internalType: 'string',
                name: 'oldName',
                type: 'string',
            },
            {
                indexed: false,
                internalType: 'string',
                name: 'newName',
                type: 'string',
            },
        ],
        name: 'RegistrarUpdated',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'address',
                name: 'by',
                type: 'address',
            },
        ],
        name: 'RegistrationPaused',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'address',
                name: 'by',
                type: 'address',
            },
        ],
        name: 'RegistrationUnpaused',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: 'string',
                name: 'safleId',
                type: 'string',
            },
            {
                indexed: false,
                internalType: 'address',
                name: 'secondaryAddress',
                type: 'address',
            },
            {
                indexed: false,
                internalType: 'bytes',
                name: 'signature',
                type: 'bytes',
            },
            {
                indexed: false,
                internalType: 'bytes',
                name: 'options',
                type: 'bytes',
            },
        ],
        name: 'RemoveSecondaryAddressInitiated',
        type: 'event',
    },
    {
        inputs: [],
        name: 'renounceOwnership',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'string',
                name: 'oldSafleId',
                type: 'string',
            },
            {
                indexed: true,
                internalType: 'string',
                name: 'newSafleId',
                type: 'string',
            },
            {
                indexed: false,
                internalType: 'address',
                name: 'primary',
                type: 'address',
            },
        ],
        name: 'SafleIDChanged',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'string',
                name: 'safleId',
                type: 'string',
            },
            {
                indexed: false,
                internalType: 'address',
                name: 'primary',
                type: 'address',
            },
        ],
        name: 'SafleIDRegistered',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'string',
                name: 'safleId',
                type: 'string',
            },
            {
                indexed: false,
                internalType: 'address',
                name: 'oldPrimary',
                type: 'address',
            },
            {
                indexed: false,
                internalType: 'address',
                name: 'newPrimary',
                type: 'address',
            },
        ],
        name: 'SafleIDUpdated',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'string',
                name: 'safleId',
                type: 'string',
            },
            {
                indexed: false,
                internalType: 'address',
                name: 'secondary',
                type: 'address',
            },
        ],
        name: 'SecondaryAddressAdded',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'string',
                name: 'safleId',
                type: 'string',
            },
            {
                indexed: false,
                internalType: 'address',
                name: 'secondary',
                type: 'address',
            },
        ],
        name: 'SecondaryAddressRemoved',
        type: 'event',
    },
    {
        inputs: [
            {
                internalType: 'uint256',
                name: '_amount',
                type: 'uint256',
            },
        ],
        name: 'setRegistrarFees',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: '_relayer',
                type: 'address',
            },
        ],
        name: 'setRelayer',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'uint256',
                name: '_amount',
                type: 'uint256',
            },
        ],
        name: 'setSafleIdFees',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: '_RegistrarStorageUtil',
                type: 'address',
            },
        ],
        name: 'setUtilImplementation',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'address',
                name: 'token',
                type: 'address',
            },
        ],
        name: 'TokenAllowed',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'address',
                name: 'token',
                type: 'address',
            },
        ],
        name: 'TokenDisallowed',
        type: 'event',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: 'newOwner',
                type: 'address',
            },
        ],
        name: 'transferOwnership',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [],
        name: 'unPauseRegistration',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: '_registrar',
                type: 'address',
            },
            {
                internalType: 'string',
                name: '_newRegistrarName',
                type: 'string',
            },
        ],
        name: 'updateRegistrar',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: 'string',
                name: 'oldSafleId',
                type: 'string',
            },
            {
                indexed: false,
                internalType: 'string',
                name: 'newSafleId',
                type: 'string',
            },
            {
                indexed: false,
                internalType: 'bytes',
                name: 'signature',
                type: 'bytes',
            },
            {
                indexed: false,
                internalType: 'bytes',
                name: 'options',
                type: 'bytes',
            },
        ],
        name: 'UpdateSafleIdInitiated',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: false,
                internalType: 'string',
                name: 'safleId',
                type: 'string',
            },
            {
                indexed: false,
                internalType: 'address',
                name: 'newPrimaryAddress',
                type: 'address',
            },
            {
                indexed: false,
                internalType: 'bytes',
                name: 'signature',
                type: 'bytes',
            },
            {
                indexed: false,
                internalType: 'bytes',
                name: 'options',
                type: 'bytes',
            },
        ],
        name: 'UpdateSafleIdPrimaryAddressInitiated',
        type: 'event',
    },
    {
        inputs: [
            {
                internalType: 'address payable',
                name: '_walletAddress',
                type: 'address',
            },
        ],
        name: 'updateWalletAddress',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        anonymous: false,
        inputs: [
            {
                indexed: true,
                internalType: 'address',
                name: 'implementation',
                type: 'address',
            },
        ],
        name: 'Upgraded',
        type: 'event',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: 'newImplementation',
                type: 'address',
            },
            {
                internalType: 'bytes',
                name: 'data',
                type: 'bytes',
            },
        ],
        name: 'upgradeToAndCall',
        outputs: [],
        stateMutability: 'payable',
        type: 'function',
    },
    {
        inputs: [],
        name: 'contractOwner',
        outputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_safleId',
                type: 'string',
            },
        ],
        name: 'getPrimaryAddress',
        outputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'getRegisteredSafleIds',
        outputs: [
            {
                internalType: 'string[]',
                name: '',
                type: 'string[]',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: 'token',
                type: 'address',
            },
        ],
        name: 'getRequiredTokenAmount',
        outputs: [
            {
                internalType: 'uint256',
                name: '',
                type: 'uint256',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_safleId',
                type: 'string',
            },
        ],
        name: 'getSecondaryAddresses',
        outputs: [
            {
                internalType: 'address[]',
                name: '',
                type: 'address[]',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
        ],
        name: 'isAddressTaken',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'isPaused',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_safleId',
                type: 'string',
            },
            {
                internalType: 'address',
                name: '_address',
                type: 'address',
            },
        ],
        name: 'isPrimaryAddress',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
        ],
        name: 'isRegisteredRegistrar',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '_safleId',
                type: 'string',
            },
            {
                internalType: 'address',
                name: '_address',
                type: 'address',
            },
        ],
        name: 'isSecondaryAddress',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'MAX_NAME_UPDATES',
        outputs: [
            {
                internalType: 'uint256',
                name: '',
                type: 'uint256',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'owner',
        outputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'proxiableUUID',
        outputs: [
            {
                internalType: 'bytes32',
                name: '',
                type: 'bytes32',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'uint256',
                name: '',
                type: 'uint256',
            },
        ],
        name: 'registeredSafleIds',
        outputs: [
            {
                internalType: 'string',
                name: '',
                type: 'string',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'registrarFees',
        outputs: [
            {
                internalType: 'uint256',
                name: '',
                type: 'uint256',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
        ],
        name: 'registrarNames',
        outputs: [
            {
                internalType: 'string',
                name: '',
                type: 'string',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '',
                type: 'string',
            },
        ],
        name: 'registrarNameToAddress',
        outputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
        ],
        name: 'Registrars',
        outputs: [
            {
                internalType: 'bool',
                name: 'isRegisteredRegistrar',
                type: 'bool',
            },
            {
                internalType: 'string',
                name: 'registrarName',
                type: 'string',
            },
            {
                internalType: 'address',
                name: 'registrarAddress',
                type: 'address',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'relayer',
        outputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'bytes',
                name: '',
                type: 'bytes',
            },
        ],
        name: 'resolveAddressFromSafleId',
        outputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
            {
                internalType: 'uint256',
                name: '',
                type: 'uint256',
            },
        ],
        name: 'resolveOldRegistrarAddress',
        outputs: [
            {
                internalType: 'bytes',
                name: '',
                type: 'bytes',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
        ],
        name: 'resolveSafleIdfromAddress',
        outputs: [
            {
                internalType: 'string',
                name: '',
                type: 'string',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'safleIdFees',
        outputs: [
            {
                internalType: 'uint256',
                name: '',
                type: 'uint256',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'totalRegistrars',
        outputs: [
            {
                internalType: 'uint256',
                name: '',
                type: 'uint256',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: '',
                type: 'address',
            },
        ],
        name: 'totalRegistrarUpdates',
        outputs: [
            {
                internalType: 'uint8',
                name: '',
                type: 'uint8',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'totalSafleIdRegistered',
        outputs: [
            {
                internalType: 'uint256',
                name: '',
                type: 'uint256',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'string',
                name: '',
                type: 'string',
            },
        ],
        name: 'unavailableSafleIds',
        outputs: [
            {
                internalType: 'bool',
                name: '',
                type: 'bool',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'UPGRADE_INTERFACE_VERSION',
        outputs: [
            {
                internalType: 'string',
                name: '',
                type: 'string',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'util',
        outputs: [
            {
                internalType: 'contract RegistrarStorageUtil',
                name: '',
                type: 'address',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'walletAddress',
        outputs: [
            {
                internalType: 'address payable',
                name: '',
                type: 'address',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
]

export default task('InitiateSafleIdTests', 'Test all initiate functions').setAction(
    async (taskArgs, hre: HardhatRuntimeEnvironment) => {
        // Get multiple signers for testing different scenarios
        const [signer1, signer2, signer3] = await hre.ethers.getSigners()
        const feeAmount = hre.ethers.utils.parseEther('0.002')
        const zeroAddress = '0x0000000000000000000000000000000000000000'

        // Create contract instance
        const RegistrarStorageChildContract = new hre.ethers.Contract(
            '0xA2C25C124D1fF9748CEF41efc7FeE555eFE5df18', // Proxy address
            RegistrarStorageABI,
            signer1
        )

        // Helper function to create signature
        const createSignature = async (signer: any, operation: string, params: any[]) => {
            const message = hre.ethers.utils.solidityKeccak256(
                params.map((p) => (typeof p === 'string' ? 'string' : 'address')),
                params.map((p) =>
                    typeof p === 'string' ? hre.ethers.utils.hexlify(hre.ethers.utils.toUtf8Bytes(p)) : p
                )
            )
            return await signer.signMessage(hre.ethers.utils.arrayify(message))
        }

        try {
            // // 1. Test initiateRegisterSafleId
            // console.log('\nTesting initiateRegisterSafleId...')
            let safleId1 = 'testSafleId1'
            // const registerSig1 = await createSignature(signer1, 'registerSafleId', [
            //     'registerSafleId',
            //     safleId1,
            //     signer1.address,
            // ])
            // try {
            //     const registerTx = await RegistrarStorageChildContract.initiateRegisterSafleId(
            //         safleId1,
            //         signer1.address,
            //         registerSig1,
            //         zeroAddress,
            //         '0x',
            //         { value: feeAmount }
            //     )
            //     const registerReceipt = await registerTx.wait()
            //     console.log('Register Transaction Hash:', registerReceipt.transactionHash)
            // } catch (error) {
            //     console.error('Error in initiateRegisterSafleId:', error)
            // }
            // await new Promise((resolve) => setTimeout(resolve, 10000))

            // // 2. Test initiateUpdateSafleId
            // console.log('\nTesting initiateUpdateSafleId...')
            const newSafleId = 'testSafleId2'
            safleId1 = newSafleId
            // const updateSig = await createSignature(signer1, 'updateSafleId', ['updateSafleId', safleId1, newSafleId])
            // try {
            //     const updateTx = await RegistrarStorageChildContract.initiateUpdateSafleId(
            //         safleId1,
            //         newSafleId,
            //         updateSig,
            //         zeroAddress,
            //         '0x',
            //         { value: feeAmount }
            //     )
            //     const updateReceipt = await updateTx.wait()
            //     console.log('Update Transaction Hash:', updateReceipt.transactionHash)
            // } catch (error) {
            //     console.error('Error in initiateUpdateSafleId:', error)
            // }
            // await new Promise((resolve) => setTimeout(resolve, 10000))

            // 3. Test initiateUpdateSafleIdPrimaryAddress
            console.log('\nTesting initiateUpdateSafleIdPrimaryAddress...')
            const updatePrimarySig = await createSignature(signer1, 'updatePrimary', [safleId1, signer2.address])
            try {
                const updatePrimaryTx = await RegistrarStorageChildContract.initiateUpdateSafleIdPrimaryAddress(
                    safleId1,
                    signer2.address,
                    updatePrimarySig,
                    '0x',
                    { value: feeAmount }
                )
                const updatePrimaryReceipt = await updatePrimaryTx.wait()
                console.log('Update Primary Transaction Hash:', updatePrimaryReceipt.transactionHash)
            } catch (error) {
                console.error('Error in initiateUpdateSafleIdPrimaryAddress:', error)
            }
            // await new Promise((resolve) => setTimeout(resolve, 10000))

            // 4. Test initiateAddSecondaryAddress
            console.log('\nTesting initiateAddSecondaryAddress...')
            // const primarySig = await createSignature(signer1, 'addSecondary', [safleId1, signer3.address])
            // const secondarySig = await createSignature(signer3, 'addSecondary', [safleId1, signer3.address])
            // try {
            //     const addSecondaryTx = await RegistrarStorageChildContract.initiateAddSecondaryAddress(
            //         safleId1,
            //         signer3.address,
            //         primarySig,
            //         secondarySig,
            //         '0x',
            //         { value: feeAmount }
            //     )
            //     const addSecondaryReceipt = await addSecondaryTx.wait()
            //     console.log('Add Secondary Transaction Hash:', addSecondaryReceipt.transactionHash)
            // } catch (error) {
            //     console.error('Error in initiateAddSecondaryAddress:', error)
            // }
            // await new Promise((resolve) => setTimeout(resolve, 10000))

            // 5. Test initiateRemoveSecondaryAddress
            // console.log('\nTesting initiateRemoveSecondaryAddress...')
            // const removeSig = await createSignature(signer1, 'removeSecondary', [safleId1, signer3.address])
            // try {
            //     const removeSecondaryTx = await RegistrarStorageChildContract.initiateRemoveSecondaryAddress(
            //         safleId1,
            //         signer3.address,
            //         removeSig,
            //         '0x',
            //         { value: feeAmount }
            //     )
            //     const removeSecondaryReceipt = await removeSecondaryTx.wait()
            //     console.log('Remove Secondary Transaction Hash:', removeSecondaryReceipt.transactionHash)
            // } catch (error) {
            //     console.error('Error in initiateRemoveSecondaryAddress:', error)
            // }
            // await new Promise((resolve) => setTimeout(resolve, 10000))

            // Get and display registered SafleIDs as a final check
            try {
                const registeredSafleIds = await RegistrarStorageChildContract.getRegisteredSafleIds()
                console.log('\nRegistered SafleIDs:', registeredSafleIds)
            } catch (error) {
                console.error('Error fetching registered SafleIDs:', error)
            }
        } catch (error) {
            console.error('Error during test execution:', error)
        }
    }
)
