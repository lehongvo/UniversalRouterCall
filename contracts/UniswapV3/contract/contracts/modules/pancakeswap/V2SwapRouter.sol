// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IUniswapV2Pair} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import {RouterImmutables} from '../../base/RouterImmutables.sol';
import {Payments} from '../Payments.sol';
import {Permit2Payments} from '../Permit2Payments.sol';
import {Constants} from '../../libraries/Constants.sol';
import {UniversalRouterHelper} from '../../libraries/UniversalRouterHelper.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';

/// @title Router for PancakeSwap v2 Trades
abstract contract V2SwapRouter is RouterImmutables, Permit2Payments {
    error V2TooLittleReceived();
    error V2TooMuchRequested();
    error V2InvalidPath();

    struct SwapVars {
        address token0;
        uint256 finalPairIndex;
        uint256 penultimatePairIndex;
        uint256 reserve0;
        uint256 reserve1; 
        uint256 amountInput;
        uint256 amountOutput;
        address nextPair;
    }

    function _v2Swap(address[] calldata path, address recipient, address pair) private {
        unchecked {
            if (path.length < 2) revert V2InvalidPath();

            SwapVars memory vars;
            // Sort tokens và lưu vào struct
            (vars.token0,) = UniversalRouterHelper.sortTokens(path[0], path[1]);
            vars.finalPairIndex = path.length - 1;
            vars.penultimatePairIndex = vars.finalPairIndex - 1;

            for (uint256 i; i < vars.finalPairIndex; i++) {
                (address input, address output) = (path[i], path[i + 1]);
                
                // Tách logic getReserves ra
                (vars.reserve0, vars.reserve1) = _getReserves(pair);
                (uint256 reserveInput, uint256 reserveOutput) = 
                    _getOrderedReserves(input, vars.token0, vars.reserve0, vars.reserve1);

                // Tính toán amounts
                vars.amountInput = ERC20(input).balanceOf(pair) - reserveInput;
                vars.amountOutput = UniversalRouterHelper.getAmountOut(
                    vars.amountInput, 
                    reserveInput, 
                    reserveOutput
                );

                // Xử lý swap
                (uint256 amount0Out, uint256 amount1Out) = 
                    input == vars.token0 ? (uint256(0), vars.amountOutput) : (vars.amountOutput, uint256(0));

                // Get next pair
                (vars.nextPair, vars.token0) = _getNextPair(
                    i, 
                    vars.penultimatePairIndex,
                    output,
                    path,
                    recipient
                );

                // Thực hiện swap
                IUniswapV2Pair(pair).swap(amount0Out, amount1Out, vars.nextPair, new bytes(0));
                pair = vars.nextPair;
            }
        }
    }

    function _getReserves(address pair) private view returns (uint256, uint256) {
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair).getReserves();
        return (reserve0, reserve1);
    }

    function _getOrderedReserves(
        address input, 
        address token0, 
        uint256 reserve0, 
        uint256 reserve1
    ) private pure returns (uint256, uint256) {
        return input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function _getNextPair(
        uint256 i,
        uint256 penultimatePairIndex,
        address output,
        address[] calldata path,
        address recipient
    ) private view returns (address nextPair, address token0) {
        if (i < penultimatePairIndex) {
            return UniversalRouterHelper.pairAndToken0For(
                PANCAKESWAP_V2_FACTORY,
                PANCAKESWAP_V2_PAIR_INIT_CODE_HASH,
                output,
                path[i + 2]
            );
        } else {
            return (recipient, address(0));
        }
    }

    /// @notice Performs a PancakeSwap v2 exact input swap
    /// @param recipient The recipient of the output tokens
    /// @param amountIn The amount of input tokens for the trade
    /// @param amountOutMinimum The minimum desired amount of output tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param payer The address that will be paying the input
    function v2SwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address[] calldata path,
        address payer
    ) internal {
        address firstPair =
            UniversalRouterHelper.pairFor(PANCAKESWAP_V2_FACTORY, PANCAKESWAP_V2_PAIR_INIT_CODE_HASH, path[0], path[1]);
        if (amountIn != Constants.ALREADY_PAID) {
            payOrPermit2Transfer(path[0], payer, firstPair, amountIn);
        }

        ERC20 tokenOut = ERC20(path[path.length - 1]);
        uint256 balanceBefore = tokenOut.balanceOf(recipient);

        _v2Swap(path, recipient, firstPair);

        uint256 amountOut = tokenOut.balanceOf(recipient) - balanceBefore;
        if (amountOut < amountOutMinimum) revert V2TooLittleReceived();
    }

    /// @notice Performs a PancakeSwap v2 exact output swap
    /// @param recipient The recipient of the output tokens
    /// @param amountOut The amount of output tokens to receive for the trade
    /// @param amountInMaximum The maximum desired amount of input tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param payer The address that will be paying the input
    function v2SwapExactOutput(
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        address[] calldata path,
        address payer
    ) internal {
        (uint256 amountIn, address firstPair) = 
            UniversalRouterHelper.getAmountInMultihop(
                PANCAKESWAP_V2_FACTORY, 
                PANCAKESWAP_V2_PAIR_INIT_CODE_HASH, 
                amountOut, 
                path
            );
            
        if (amountIn > amountInMaximum) revert V2TooMuchRequested();

        payOrPermit2Transfer(path[0], payer, firstPair, amountIn);
        _v2Swap(path, recipient, firstPair);
    }
}