#pragma once

namespace GameConfig {
// Economy
constexpr int StartingGold = 10000;

// Repair and upgrades
constexpr int RepairCost = 100;
constexpr int UpgradeSpeedGold = 100;
constexpr int UpgradeSpeedWood = 50;
constexpr int UpgradeFireRateGold = 150;
constexpr int UpgradeFireRateWood = 30;

// Quests
constexpr int QuestMerchantCost = 30;
constexpr int QuestMerchantReward = 150;
constexpr int QuestMilitaryCost = 150;
constexpr int QuestMilitaryReward = 250;
constexpr int QuestDiplomaticCost = 20;
constexpr int QuestDiplomaticReward = 100;

// Resources (Batch of 50)
constexpr int SellBatchWoodGold = 20;
constexpr int SellBatchWaterGold = 20;
constexpr int SellBatchFoodGold = 20;

// Resources (Single scale)
constexpr int SellSingleFoodGold = 10;
constexpr int SellSingleWoodGold = 15;

// Wind Dynamics
constexpr float BaseWindStrengthMultiplier = 0.2f; // Base random range
constexpr float MaxWindStrengthMultiplier =
    1.0f; // Max random range added to base

// Ship Base Speeds (Max Speed)
constexpr float SloopSpeed = 150.0f;
constexpr float BrigantineSpeed = 200.0f;
constexpr float GalleonSpeed = 220.0f;

// Ship Base Health (Max HP)
constexpr float SloopHP = 150.0f;
constexpr float BrigantineHP = 200.0f;
constexpr float GalleonHP = 300.0f;

// Ship Base Cooldowns
constexpr float SloopCooldown = 1.0f;
constexpr float BrigantineCooldown = 1.5f;
constexpr float GalleonCooldown = 2.0f;
} // namespace GameConfig
