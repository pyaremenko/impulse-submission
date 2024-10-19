// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/contracts/libraries/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/contracts/types/BalanceDelta.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DiscountNFT is ERC721Enumerable, Ownable {
    uint256 public nextTokenId;
    mapping(uint256 => uint8) public discounts; // Discounts in percentage (e.g., 10%)

    constructor() ERC721("Discount NFT", "DNFT") {}

    function mintDiscountNFT(address to, uint8 discount) external onlyOwner {
        discounts[nextTokenId] = discount;
        _mint(to, nextTokenId);
        nextTokenId++;
    }

    function getDiscount(uint256 tokenId) external view returns (uint8) {
        return discounts[tokenId];
    }
}

contract DiscountHook is BaseHook {
    DiscountNFT public discountNFT;
    uint256 public baseFee = 20; // 20% base fee

    constructor(
        IPoolManager _poolManager,
        address _discountNFT
    ) BaseHook(_poolManager) {
        discountNFT = DiscountNFT(_discountNFT);
    }

    // Function to calculate the discount based on NFTs owned by the buyer
    function calculateDiscount(address buyer) public view returns (uint8) {
        uint256 balance = discountNFT.balanceOf(buyer);
        uint8 maxDiscount = 0;
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = discountNFT.tokenOfOwnerByIndex(buyer, i);
            uint8 discount = discountNFT.getDiscount(tokenId);
            if (discount > maxDiscount) {
                maxDiscount = discount;
            }
        }
        return maxDiscount;
    }

    // Hook function that applies discount before the swap
    function beforeSwap(
        address buyer,
        IPoolManager.PoolKey calldata poolKey,
        IPoolManager.SwapParams calldata swapParams
    ) external override returns (bytes4) {
        // Calculate buyer discount based on owned NFTs
        uint8 discount = calculateDiscount(buyer);
        uint256 effectiveFee = baseFee - discount;
        uint256 fee = (swapParams.amountSpecified * effectiveFee) / 100;

        // Handle fee logic (fee calculation, distribution, etc.)
        // Store or process the fee as needed

        return BaseHook.beforeSwap.selector;
    }

    // Hook function after the swap is completed
    function afterSwap(
        address buyer,
        IPoolManager.PoolKey calldata poolKey,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta balanceDelta
    ) external override returns (bytes4) {
        // Post-swap logic can be added here, like updating states or minting NFTs

        // Optionally mint a new NFT with a random discount for the buyer
        uint8 newDiscount = randomDiscount();
        discountNFT.mintDiscountNFT(buyer, newDiscount);

        return BaseHook.afterSwap.selector;
    }

    // Simple function to generate a random discount for new NFTs
    function randomDiscount() internal view returns (uint8) {
        return
            uint8(
                (uint256(
                    keccak256(
                        abi.encodePacked(block.timestamp, block.difficulty)
                    )
                ) % 10) + 5
            ); // Random discount between 5% to 15%
    }

    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        Hooks.Calls memory calls;
        calls.beforeSwap = true;
        calls.afterSwap = true;
        return calls;
    }
}
