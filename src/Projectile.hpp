#pragma once
#include "Entity.hpp"

// Forward declaration
class Ship;

class Projectile : public Entity {
public:
  Vector3 velocity;
  float lifeTime;
  float damage;
  bool isPlayerOwned;
  Ship *owner;

  Projectile(Vector3 pos, Vector3 vel, float dmg, bool fromPlayer, Ship *o);

  void Update(float dt) override;
  void Draw() override;
};
