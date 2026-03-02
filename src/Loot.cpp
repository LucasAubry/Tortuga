#include "Loot.hpp"
#include <raymath.h>

Loot::Loot(Vector3 pos, LootType lt, int amt)
    : Entity(pos, 8.0f), type(lt), amount(amt), floatTimer(0.0f) {}

void Loot::Update(float dt) {
  if (!active)
    return;
  floatTimer += dt;
  // Bobbing animation
  position.y = 5.0f + sinf(floatTimer * 3.0f) * 2.0f;
}

void Loot::Draw() {
  if (!active)
    return;

  Color c = WHITE;
  if (type == LootType::LOOT_GOLD)
    c = YELLOW;
  if (type == LootType::LOOT_WOOD)
    c = DARKBROWN;
  if (type == LootType::LOOT_AMMO)
    c = DARKGRAY;
  if (type == LootType::LOOT_FOOD)
    c = RED;
  if (type == LootType::LOOT_WATER)
    c = BLUE;

  DrawCube(position, radius, radius, radius, c);
  DrawCubeWires(position, radius, radius, radius, BLACK);
}
