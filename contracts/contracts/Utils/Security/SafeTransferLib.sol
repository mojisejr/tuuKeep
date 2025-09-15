// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title SafeTransferLib
 * @dev Safe transfer utilities for ERC-20 and ERC-721 tokens with comprehensive error handling
 *
 * Features:
 * - Return value validation for ERC-20 transfers
 * - Gas monitoring and optimization for cabinet operations
 * - Batch transfer capabilities for efficient asset management
 * - Comprehensive error handling with detailed revert messages
 * - Integration with cabinet asset management system
 * - Support for tokens with and without return values
 *
 * Usage:
 * - Use for all token transfers in TuuKeep platform
 * - Particularly important for cabinet asset deposits/withdrawals
 * - Marketplace trading operations
 * - TuuCoin transfers and burns
 */
library SafeTransferLib {
    using SafeERC20 for IERC20;
    using Address for address;

    /// @dev Transfer result information
    struct TransferResult {
        bool success;
        bytes data;
        uint256 gasUsed;
        string errorMessage;
    }

    /// @dev Batch transfer data structure
    struct ERC20Transfer {
        IERC20 token;
        address to;
        uint256 amount;
    }

    /// @dev ERC721 transfer data structure
    struct ERC721Transfer {
        IERC721 token;
        address from;
        address to;
        uint256 tokenId;
    }

    /// @dev Custom errors for gas efficiency
    error TransferFailed(address token, address from, address to, uint256 amount);
    error InvalidTransferParams(string reason);
    error InsufficientBalance(address token, address account, uint256 required, uint256 available);

    /// @dev Events for monitoring and analytics
    event SafeTransferExecuted(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 gasUsed
    );

    event BatchTransferCompleted(
        uint256 successCount,
        uint256 failureCount,
        uint256 totalGasUsed
    );

    /**
     * @dev Safely transfer ERC-20 tokens with comprehensive error handling
     * @param token The ERC-20 token contract
     * @param to The recipient address
     * @param amount The amount to transfer
     * @return result Transfer result with success status and gas usage
     */
    function safeTransferERC20(
        IERC20 token,
        address to,
        uint256 amount
    ) external returns (TransferResult memory result) {
        uint256 gasStart = gasleft();

        // Input validation
        if (address(token) == address(0)) {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: "Invalid token address"
            });
        }

        if (to == address(0)) {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: "Invalid recipient address"
            });
        }

        if (amount == 0) {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: "Amount cannot be zero"
            });
        }

        // Check balance
        uint256 balance = token.balanceOf(address(this));
        if (balance < amount) {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: "Insufficient balance"
            });
        }

        // Execute transfer
        try token.safeTransfer(to, amount) {
            uint256 gasUsed = gasStart - gasleft();
            emit SafeTransferExecuted(address(token), address(this), to, amount, gasUsed);

            return TransferResult({
                success: true,
                data: "",
                gasUsed: gasUsed,
                errorMessage: ""
            });
        } catch Error(string memory reason) {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: reason
            });
        } catch (bytes memory data) {
            return TransferResult({
                success: false,
                data: data,
                gasUsed: gasStart - gasleft(),
                errorMessage: "Transfer failed with low-level error"
            });
        }
    }

    /**
     * @dev Safely transfer ERC-20 tokens from one address to another
     * @param token The ERC-20 token contract
     * @param from The sender address
     * @param to The recipient address
     * @param amount The amount to transfer
     * @return result Transfer result with success status and gas usage
     */
    function safeTransferFromERC20(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) external returns (TransferResult memory result) {
        uint256 gasStart = gasleft();

        // Input validation
        if (address(token) == address(0) || from == address(0) || to == address(0)) {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: "Invalid address parameters"
            });
        }

        if (amount == 0) {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: "Amount cannot be zero"
            });
        }

        // Check balance and allowance
        uint256 balance = token.balanceOf(from);
        uint256 allowance = token.allowance(from, address(this));

        if (balance < amount) {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: "Insufficient balance"
            });
        }

        if (allowance < amount) {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: "Insufficient allowance"
            });
        }

        // Execute transfer
        try token.safeTransferFrom(from, to, amount) {
            uint256 gasUsed = gasStart - gasleft();
            emit SafeTransferExecuted(address(token), from, to, amount, gasUsed);

            return TransferResult({
                success: true,
                data: "",
                gasUsed: gasUsed,
                errorMessage: ""
            });
        } catch Error(string memory reason) {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: reason
            });
        } catch (bytes memory data) {
            return TransferResult({
                success: false,
                data: data,
                gasUsed: gasStart - gasleft(),
                errorMessage: "TransferFrom failed with low-level error"
            });
        }
    }

    /**
     * @dev Safely transfer ERC-721 token
     * @param token The ERC-721 token contract
     * @param from The sender address
     * @param to The recipient address
     * @param tokenId The token ID to transfer
     * @return result Transfer result with success status and gas usage
     */
    function safeTransferERC721(
        IERC721 token,
        address from,
        address to,
        uint256 tokenId
    ) external returns (TransferResult memory result) {
        uint256 gasStart = gasleft();

        // Input validation
        if (address(token) == address(0) || from == address(0) || to == address(0)) {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: "Invalid address parameters"
            });
        }

        // Check ownership
        try token.ownerOf(tokenId) returns (address owner) {
            if (owner != from) {
                return TransferResult({
                    success: false,
                    data: "",
                    gasUsed: gasStart - gasleft(),
                    errorMessage: "Token not owned by from address"
                });
            }
        } catch {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: "Token does not exist"
            });
        }

        // Check approval
        try token.getApproved(tokenId) returns (address approved) {
            bool isApproved = (approved == address(this)) ||
                             token.isApprovedForAll(from, address(this)) ||
                             (from == address(this));

            if (!isApproved) {
                return TransferResult({
                    success: false,
                    data: "",
                    gasUsed: gasStart - gasleft(),
                    errorMessage: "Transfer not approved"
                });
            }
        } catch {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: "Failed to check approval"
            });
        }

        // Execute transfer
        try token.safeTransferFrom(from, to, tokenId) {
            uint256 gasUsed = gasStart - gasleft();
            emit SafeTransferExecuted(address(token), from, to, tokenId, gasUsed);

            return TransferResult({
                success: true,
                data: "",
                gasUsed: gasUsed,
                errorMessage: ""
            });
        } catch Error(string memory reason) {
            return TransferResult({
                success: false,
                data: "",
                gasUsed: gasStart - gasleft(),
                errorMessage: reason
            });
        } catch (bytes memory data) {
            return TransferResult({
                success: false,
                data: data,
                gasUsed: gasStart - gasleft(),
                errorMessage: "ERC721 transfer failed with low-level error"
            });
        }
    }

    /**
     * @dev Execute multiple ERC-20 transfers in a single transaction
     * Gas-efficient for cabinet asset management
     * @param transfers Array of transfer data
     * @return results Array of transfer results
     */
    function batchTransferERC20(ERC20Transfer[] calldata transfers)
        external
        returns (TransferResult[] memory results)
    {
        uint256 totalGasStart = gasleft();
        results = new TransferResult[](transfers.length);

        uint256 successCount = 0;
        uint256 failureCount = 0;

        for (uint256 i = 0; i < transfers.length; i++) {
            results[i] = this.safeTransferERC20(
                transfers[i].token,
                transfers[i].to,
                transfers[i].amount
            );

            if (results[i].success) {
                successCount++;
            } else {
                failureCount++;
            }
        }

        uint256 totalGasUsed = totalGasStart - gasleft();
        emit BatchTransferCompleted(successCount, failureCount, totalGasUsed);
    }

    /**
     * @dev Execute multiple ERC-721 transfers in a single transaction
     * @param transfers Array of ERC-721 transfer data
     * @return results Array of transfer results
     */
    function batchTransferERC721(ERC721Transfer[] calldata transfers)
        external
        returns (TransferResult[] memory results)
    {
        uint256 totalGasStart = gasleft();
        results = new TransferResult[](transfers.length);

        uint256 successCount = 0;
        uint256 failureCount = 0;

        for (uint256 i = 0; i < transfers.length; i++) {
            results[i] = this.safeTransferERC721(
                transfers[i].token,
                transfers[i].from,
                transfers[i].to,
                transfers[i].tokenId
            );

            if (results[i].success) {
                successCount++;
            } else {
                failureCount++;
            }
        }

        uint256 totalGasUsed = totalGasStart - gasleft();
        emit BatchTransferCompleted(successCount, failureCount, totalGasUsed);
    }

    /**
     * @dev Check if an ERC-20 transfer would succeed without executing it
     * Useful for pre-validation in UI
     * @param token The ERC-20 token contract
     * @param from The sender address
     * @param to The recipient address
     * @param amount The amount to transfer
     * @return success Whether the transfer would succeed
     * @return reason Failure reason if applicable
     */
    function canTransferERC20(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) external view returns (bool success, string memory reason) {
        if (address(token) == address(0)) {
            return (false, "Invalid token address");
        }
        if (from == address(0) || to == address(0)) {
            return (false, "Invalid address parameters");
        }
        if (amount == 0) {
            return (false, "Amount cannot be zero");
        }

        uint256 balance = token.balanceOf(from);
        if (balance < amount) {
            return (false, "Insufficient balance");
        }

        if (from != address(this)) {
            uint256 allowance = token.allowance(from, address(this));
            if (allowance < amount) {
                return (false, "Insufficient allowance");
            }
        }

        return (true, "");
    }

    /**
     * @dev Check if an ERC-721 transfer would succeed without executing it
     * @param token The ERC-721 token contract
     * @param from The sender address
     * @param to The recipient address
     * @param tokenId The token ID to transfer
     * @return success Whether the transfer would succeed
     * @return reason Failure reason if applicable
     */
    function canTransferERC721(
        IERC721 token,
        address from,
        address to,
        uint256 tokenId
    ) external view returns (bool success, string memory reason) {
        if (address(token) == address(0)) {
            return (false, "Invalid token address");
        }
        if (from == address(0) || to == address(0)) {
            return (false, "Invalid address parameters");
        }

        try token.ownerOf(tokenId) returns (address owner) {
            if (owner != from) {
                return (false, "Token not owned by from address");
            }
        } catch {
            return (false, "Token does not exist");
        }

        try token.getApproved(tokenId) returns (address approved) {
            bool isApproved = (approved == address(this)) ||
                             token.isApprovedForAll(from, address(this)) ||
                             (from == address(this));

            if (!isApproved) {
                return (false, "Transfer not approved");
            }
        } catch {
            return (false, "Failed to check approval");
        }

        return (true, "");
    }
}