#include "Projectile.hpp"
#include <raymath.h>

Projectile::Projectile(Vector3 pos, Vector3 vel, float dmg, bool fromPlayer,
                       Ship *o)
    : Entity(pos, 4.0f), velocity(vel), lifeTime(3.0f), damage(dmg),
      isPlayerOwned(fromPlayer), owner(o) {}

void Projectile::Update(float dt) {
  if (!active)
    return;

  position.x += velocity.x * dt;
  position.y += velocity.y * dt;
  position.z += velocity.z * dt;

  lifeTime -= dt;
  if (lifeTime <= 0) {
    active = false;
  }
}

void Projectile::Draw() {
  if (!active)
    return;
  Color color = BLACK;
  DrawSphere(position, radius, color);
}
