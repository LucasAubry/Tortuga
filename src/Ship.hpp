#pragma once
#include "Entity.hpp"

enum class ShipClass { SLOOP, BRIGANTINE, GALLEON };

class Ship : public Entity {
public:
  bool isPlayer;
  ShipClass type;
  Color color;

  float hp;
  float maxHp;
  float speed;
  float maxSpeed;
  float acceleration;
  float turnSpeed;
  float rotation;       // in degrees
  float turretRotation; // Fixed cannons now
  float cooldown;
  float maxCooldown;
  float damage;

  int ammo;
  int maxAmmo;

  // Inventory
  int gold;
  int wood;
  int food;
  int water;
  int fish;

  // Upgrades
  int speedLevel;
  int fireRateLevel;
  int extraCannons;
  int upgradesPurchased;

  // Movement System
  Vector3 targetPosition;

  // AI specific
  float aiStateTimer;
  bool isWandering;
  bool isFleeingToRepair;
  Ship *targetAttacker;

  Ship(Vector3 pos, bool player, ShipClass shipType, Color c);

  void Update(float dt) override;
  void Draw() override;

  void TakeDamage(float amount, Ship *attacker);
  void Heal(float amount);
};
