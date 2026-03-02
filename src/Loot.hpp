#pragma once
#include "Entity.hpp"

enum class LootType { LOOT_GOLD, LOOT_WOOD, LOOT_AMMO, LOOT_FOOD, LOOT_WATER };

class Loot : public Entity {
public:
  LootType type;
  int amount;
  float floatTimer;

  Loot(Vector3 pos, LootType lt, int amt);

  void Update(float dt) override;
  void Draw() override;
};
