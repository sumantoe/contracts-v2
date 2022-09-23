//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "./MessageBridge.sol";
import "./utils/Lib_MerkleTree.sol";

struct PendingBundle {
    bytes32[] messageIds;
    uint256 fees;
}

struct Route {
    uint256 chainId;
    uint256 messageFee;
    uint256 maxBundleMessages;
}

library Lib_PendingBundle {
    using Lib_MerkleTree for bytes32;

    function getBundleRoot(PendingBundle storage pendingBundle) internal view returns (bytes32) {
        return Lib_MerkleTree.getMerkleRoot(pendingBundle.messageIds);
    }
}

interface IHubMessageBridge {
    function receiveOrForwardMessageBundle(
        bytes32 bundleRoot,
        uint256 bundleFees,
        uint256 toChainId,
        uint256 commitTime
    ) external payable;
}

contract SpokeMessageBridge is MessageBridge {
    using Lib_PendingBundle for PendingBundle;
    using MessageLibrary for Message;

    address private constant DEFAULT_XDOMAIN_SENDER = 0x000000000000000000000000000000000000dEaD;
    address private xDomainSender = DEFAULT_XDOMAIN_SENDER;

    IHubMessageBridge public hubBridge;
    address public hubFeeDistributor; // hub bridge and feeDistributor should always be set as pair
    mapping(uint256 => uint256) routeMessageFee;
    mapping(uint256 => uint256) routeMaxBundleMessages;

    mapping(uint256 => PendingBundle) public pendingBundleForChainId;

    // Message nonce
    uint256 public messageNonce = uint256(keccak256(abi.encodePacked(getChainId(), "SpokeMessageBridge v1.0")));

    // Fee collection
    uint256 public totalPendingFees;
    uint256 public maxPendingFees; // ToDo: Add setter

    constructor(IHubMessageBridge _hubBridge, address _hubFeeDistributor, Route[] memory routes) {
        hubBridge = _hubBridge;
        hubFeeDistributor = _hubFeeDistributor;
        for (uint256 i = 0; i < routes.length; i++) {
            // ToDo: require chainId is not 0
            // ToDo: require messageFee is not 0
            // ToDo: require maxBundleMessages is not 0
            Route memory route = routes[i];
            routeMessageFee[route.chainId] = route.messageFee;
            routeMaxBundleMessages[route.chainId] = route.maxBundleMessages;
        }
    }

    function sendMessage(
        uint256 toChainId,
        address to,
        bytes calldata data
    )
        external
        override
        payable
    {
        uint256 messageFee = routeMessageFee[toChainId];
        if (messageFee != msg.value) {
            revert IncorrectFee(messageFee, msg.value);
        }
        uint256 fromChainId = getChainId();

        Message memory message = Message(
            messageNonce,
            fromChainId,
            msg.sender,
            to,
            data
        );
        messageNonce++;

        bytes32 messageId = message.getMessageId();
        PendingBundle storage pendingBundle = pendingBundleForChainId[toChainId];
        pendingBundle.messageIds.push(messageId);
        pendingBundle.fees = pendingBundle.fees + messageFee;

        uint256 maxBundleMessages = routeMaxBundleMessages[toChainId];
        if (pendingBundle.messageIds.length == maxBundleMessages) {
            _commitMessageBundle(toChainId);
        }
    }

    function commitMessageBundle(uint256 toChainId) external payable {
        uint256 totalFees = pendingBundleForChainId[toChainId].fees + msg.value;
        uint256 messageFee = routeMessageFee[toChainId];
        uint256 numMessages = routeMaxBundleMessages[toChainId];
        uint256 fullBundleFee = messageFee * numMessages;
        if (fullBundleFee > totalFees) {
            revert NotEnoughFees(fullBundleFee, totalFees);
        }
        _commitMessageBundle(toChainId);
    }

    function _commitMessageBundle(uint256 toChainId) private {
        PendingBundle storage pendingBundle = pendingBundleForChainId[toChainId];
        bytes32 bundleRoot = pendingBundle.getBundleRoot();
        uint256 pendingFees = pendingBundle.fees;
        delete pendingBundleForChainId[toChainId];

        totalPendingFees += pendingFees;
        if (totalPendingFees >= maxPendingFees) {
            _flushFees();
        }

        hubBridge.receiveOrForwardMessageBundle(
            bundleRoot,
            pendingFees,
            toChainId,
            block.timestamp
        );
    }

    function receiveMessageBundle(
        bytes32 bundleRoot,
        uint256 fromChainId
    )
        external
        payable
    {
        bytes32 bundleId = keccak256(abi.encodePacked(bundleRoot, getChainId()));
        bundles[bundleId] = ConfirmedBundle(fromChainId, bundleRoot);
    }

    // Internal

    function _flushFees() internal {
        // Send fees to l1
        _sendToHub(totalPendingFees);
        totalPendingFees = 0;
    }

    function _sendToHub(uint256 amount) internal virtual {
        (bool success, ) = hubFeeDistributor.call{value: amount}("");
        if (!success) revert(); // TransferFailed(to, amount);
    }
}
