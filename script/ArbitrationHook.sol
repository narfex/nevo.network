// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "../lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "../lib/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "../lib/v4-core/src/types/BalanceDelta.sol";
import {IHooks} from "../lib/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "../lib/v4-core/src/libraries/Hooks.sol";
import {Ownable} from "./lib/openzeppelin/contracts/access/Ownable.sol";

/// @title Arbitration Hook for P2P Service
/// @notice Includes logic to enforce lawyer availability and activity in P2P transactions
contract ArbitrationHook is IHooks, Ownable {
    struct Lawyer {
        bool isActive;
        bool[7][24] schedule;
    }

    mapping(address => Lawyer) private _lawyers;
    mapping(address => bool) private _isLawyer;
    address[] public lawyerList;

    event LawyerAdded(address indexed lawyer);
    event LawyerRemoved(address indexed lawyer);

    modifier onlyLawyer() {
        require(_isLawyer[msg.sender], "You are not a registered lawyer");
        _;
    }

    modifier lawyerIsActive(address lawyer) {
        require(_isLawyer[lawyer], "Not a registered lawyer");
        require(_lawyers[lawyer].isActive, "Lawyer is not active");
        _;
    }

    constructor() {}

    /// @notice Add a new lawyer to the registry
    /// @param lawyer Address of the lawyer to add
    function addLawyer(address lawyer) external onlyOwner {
        require(!_isLawyer[lawyer], "Lawyer already added");
        _isLawyer[lawyer] = true;
        lawyerList.push(lawyer);

        for (uint8 day = 0; day < 7; day++) {
            for (uint8 hour = 0; hour < 24; hour++) {
                _lawyers[lawyer].schedule[day][hour] = true;
            }
        }
        _lawyers[lawyer].isActive = true;

        emit LawyerAdded(lawyer);
    }

    /// @notice Remove a lawyer from the registry
    /// @param lawyer Address of the lawyer to remove
    function removeLawyer(address lawyer) external onlyOwner {
        require(_isLawyer[lawyer], "Lawyer not found");
        delete _lawyers[lawyer];
        _isLawyer[lawyer] = false;

        for (uint i = 0; i < lawyerList.length; i++) {
            if (lawyerList[i] == lawyer) {
                lawyerList[i] = lawyerList[lawyerList.length - 1];
                lawyerList.pop();
                break;
            }
        }

        emit LawyerRemoved(lawyer);
    }

    /// @notice Set the schedule for a lawyer
    /// @param schedule Availability schedule ([day][hour] => isActive)
    function setSchedule(bool[7][24] calldata schedule) external onlyLawyer {
        _lawyers[msg.sender].schedule = schedule;
    }

    /// @notice Set the active status of a lawyer
    /// @param isActive True if the lawyer should be marked as active
    function setIsActive(bool isActive) external onlyLawyer {
        _lawyers[msg.sender].isActive = isActive;
    }

    /// @notice Check if a lawyer is active now
    /// @param lawyer Address of the lawyer
    /// @return True if the lawyer is active
    function isLawyerActive(address lawyer) public view returns (bool) {
        if (!_isLawyer[lawyer] || !_lawyers[lawyer].isActive) return false;

        uint8 day = uint8((block.timestamp / 1 days + 4) % 7); // Day of the week (0 = Sunday)
        uint8 hour = uint8((block.timestamp / 1 hours) % 24);  // Hour of the day (0-23)

        return _lawyers[lawyer].schedule[day][hour];
    }

    /// @notice Hook called before a swap is executed
    /// @param sender Address initiating the swap
    /// @param key PoolKey of the pool being swapped
    /// @param params Swap parameters
    /// @param hookData Additional data for the hook
    function beforeSwap(
        address sender,
        PoolKey memory key,
        IPoolManager.SwapParams memory params,
        bytes calldata hookData
    ) external view override lawyerIsActive(sender) {
        // Custom pre-swap logic
    }

    /// @notice Hook called after a swap is executed
    /// @param sender Address initiating the swap
    /// @param key PoolKey of the pool being swapped
    /// @param params Swap parameters
    /// @param delta Balance deltas after the swap
    /// @param hookData Additional data for the hook
  function afterSwap(
    address sender,
    PoolKey memory key,
    IPoolManager.SwapParams memory params,
    BalanceDelta delta, // Use the imported BalanceDelta type
    bytes calldata hookData
) external pure override {
}


    /// @notice Hook function metadata
    function getHooksCalls() external pure override returns (Hooks.Call[] memory calls) {
        calls = new Hooks.Call ; // Inize array with size 2
        calls[0] = Hooks.Call.BeforeSwap;
        calls[1] = Hooks.Call.AfterSwap;
        return calls;
    }
}
