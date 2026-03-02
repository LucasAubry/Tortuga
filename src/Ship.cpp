#include "Ship.hpp"
#include "Game.hpp"
#include "GameConfig.hpp"
#include <math.h>
#include <raymath.h>
#include <rlgl.h>

Ship::Ship(Vector3 pos, bool player, ShipClass shipType, Color c)
    : Entity(pos, 20.0f), isPlayer(player), type(shipType), color(c),
      rotation(0.0f), turretRotation(0.0f), cooldown(0.0f), aiStateTimer(0.0f) {

  gold = 0;
  wood = 0;
  food = 100;
  water = 100;
  fish = 0;
  speedLevel = 0;
  fireRateLevel = 0;
  extraCannons = 0;
  upgradesPurchased = 0;
  targetPosition = pos;
  isWandering = true;
  isFleeingToRepair = false;
  targetAttacker = nullptr;

  switch (type) {
  case ShipClass::SLOOP:
    maxHp = GameConfig::SloopHP;
    maxSpeed = GameConfig::SloopSpeed;
    acceleration = 120.0f;
    turnSpeed = 180.0f; // Very high turn
    maxCooldown = GameConfig::SloopCooldown;
    damage = 20.0f;
    radius = 15.0f;
    maxAmmo = 20;
    break;
  case ShipClass::BRIGANTINE:
    maxHp = GameConfig::BrigantineHP;
    maxSpeed = GameConfig::BrigantineSpeed;
    acceleration = 140.0f;
    turnSpeed = 120.0f; // Medium turn
    maxCooldown = GameConfig::BrigantineCooldown;
    damage = 30.0f;
    radius = 20.0f;
    maxAmmo = 30;
    break;
  case ShipClass::GALLEON:
    maxHp = GameConfig::GalleonHP;
    maxSpeed = GameConfig::GalleonSpeed;
    acceleration = 100.0f;
    turnSpeed = 80.0f; // Slow turn
    maxCooldown = GameConfig::GalleonCooldown;
    damage = 40.0f;
    radius = 25.0f;
    maxAmmo = 40;
    break;
  }
  hp = maxHp;
  ammo = maxAmmo;
  speed = 0.0f;
  position.y = 5.0f;
}

void Ship::TakeDamage(float amount, Ship *attacker) {
  hp -= amount;

  if (!isPlayer && attacker) {
    // AI agros attacker
    isWandering = false;
    targetAttacker = attacker;
  }

  if (hp <= 0) {
    active = false;
    hp = 0;
  }
}

void Ship::Heal(float amount) {
  hp += amount;
  if (hp > maxHp)
    hp = maxHp;
}

void Ship::Update(float dt) {
  if (!active || Game::GetInstance()->state == GameState::TOWN_MENU ||
      Game::GetInstance()->state == GameState::SETTINGS)
    return;

  if (cooldown > 0)
    cooldown -= dt;

  if (isPlayer) {
    Game *game = Game::GetInstance();
    // Keyboard Movement    // Forward / Backward with Brake Mechanic
    if (IsKeyDown(game->keyUp)) {
      if (speed < 0)
        speed += acceleration * 3.0f * dt; // Brake when moving backward
      else
        speed += acceleration * dt;
    }
    if (IsKeyDown(game->keyDown)) {
      if (speed > 0)
        speed -= acceleration * 3.0f * dt; // Brake when moving forward
      else
        speed -= acceleration * dt;
    }

    // Turning
    if (IsKeyDown(game->keyLeft)) {
      rotation -= turnSpeed * dt;
    }
    if (IsKeyDown(game->keyRight)) {
      rotation += turnSpeed * dt;
    }

    // Braking friction if no keys pressed
    if (!IsKeyDown(game->keyUp) && !IsKeyDown(game->keyDown)) {
      if (speed > 0)
        speed -= (acceleration * 0.5f) * dt;
      if (speed < 0)
        speed += (acceleration * 0.5f) * dt;
      if (fabs(speed) < 5.0f)
        speed = 0.0f;
    }

    // Broadside Combat (Directional Firing based on Space)
    bool fireKeyPressed = IsKeyPressed(game->keyFire);

    if (fireKeyPressed && cooldown <= 0 && ammo > 0) {
      cooldown = maxCooldown;
      ammo -= 1;

      int numShots = 1;
      if (type == ShipClass::BRIGANTINE)
        numShots = 2;
      if (type == ShipClass::GALLEON)
        numShots = 3;

      numShots += extraCannons;

      Vector3 rightVec = {cosf((rotation + 90.0f) * DEG2RAD), 0.0f,
                          sinf((rotation + 90.0f) * DEG2RAD)};
      Vector3 leftVec = {cosf((rotation - 90.0f) * DEG2RAD), 0.0f,
                         sinf((rotation - 90.0f) * DEG2RAD)};
      Vector3 forwardDir = {cosf(rotation * DEG2RAD), 0.0f,
                            sinf(rotation * DEG2RAD)};

      for (int i = 0; i < numShots; i++) {
        float offset = (numShots > 1)
                           ? ((i - (numShots - 1) / 2.0f) * radius * 0.4f)
                           : 0.0f;
        Vector3 startPos = {position.x + forwardDir.x * offset, 10.0f,
                            position.z + forwardDir.z * offset};

        Vector3 vStar = {rightVec.x * 400.0f + forwardDir.x * speed, 0.0f,
                         rightVec.z * 400.0f + forwardDir.z * speed};
        game->SpawnProjectile(startPos, vStar, damage, true, this);

        Vector3 vPort = {leftVec.x * 400.0f + forwardDir.x * speed, 0.0f,
                         leftVec.z * 400.0f + forwardDir.z * speed};
        game->SpawnProjectile(startPos, vPort, damage, true, this);
      }
    }

  } else {
    // AI Smart Logic
    if (hp < maxHp * 0.3f && !isFleeingToRepair) {
      isFleeingToRepair = true;
      isWandering = false;
      targetAttacker = nullptr;
      float closestDist = 999999.0f;
      for (auto &island : Game::GetInstance()->islands) {
        float dx = position.x - island.position.x;
        float dz = position.z - island.position.z;
        float dist = sqrtf(dx * dx + dz * dz);
        if (dist < closestDist) {
          closestDist = dist;
          targetPosition = island.position;
        }
      }
    }

    if (isFleeingToRepair) {
      float dx = targetPosition.x - position.x;
      float dz = targetPosition.z - position.z;
      float distToStr = sqrtf(dx * dx + dz * dz);

      if (distToStr < radius + 150.0f) { // Docked
        hp = maxHp;
        ammo = maxAmmo;
        isFleeingToRepair = false;
        isWandering = true;
      } else {
        speed += acceleration * dt;
        float targetAngle = atan2f(dz, dx) * RAD2DEG;
        float angleDiff = targetAngle - rotation;
        while (angleDiff > 180.0f)
          angleDiff -= 360.0f;
        while (angleDiff < -180.0f)
          angleDiff += 360.0f;
        if (angleDiff > 2.0f)
          rotation += turnSpeed * dt;
        else if (angleDiff < -2.0f)
          rotation -= turnSpeed * dt;
      }
    } else if (isWandering) {
      // Occasional AI Infighting
      if (rand() % 500 == 0) {
        for (auto &ship : Game::GetInstance()->ships) {
          if (&ship != this && !ship.isPlayer && ship.active &&
              !ship.isFleeingToRepair) {
            float ddx = position.x - ship.position.x;
            float ddz = position.z - ship.position.z;
            if (sqrtf(ddx * ddx + ddz * ddz) < 3000.0f) {
              targetAttacker = &ship;
              isWandering = false;
              break;
            }
          }
        }
      }
      // Pick a random target if close to current
      float distStr = Vector3Distance(position, targetPosition);
      if (distStr < 50.0f) {
        bool validTarget = false;
        while (!validTarget) {
          targetPosition.x = position.x + (rand() % 2000 - 1000);
          targetPosition.z = position.z + (rand() % 2000 - 1000);
          validTarget = true;
          for (auto &island : Game::GetInstance()->islands) {
            float dx = targetPosition.x - island.position.x;
            float dz = targetPosition.z - island.position.z;
            if (sqrtf(dx * dx + dz * dz) < island.radius + 200.0f) {
              validTarget = false;
              break;
            }
          }
        }
      }
      speed += (acceleration * 0.5f) * dt; // wander slowly

      // Steer
      float dx = targetPosition.x - position.x;
      float dz = targetPosition.z - position.z;
      float targetAngle = atan2f(dz, dx) * RAD2DEG;
      float angleDiff = targetAngle - rotation;
      while (angleDiff > 180.0f)
        angleDiff -= 360.0f;
      while (angleDiff < -180.0f)
        angleDiff += 360.0f;
      if (angleDiff > 2.0f)
        rotation += turnSpeed * dt;
      else if (angleDiff < -2.0f)
        rotation -= turnSpeed * dt;

    } else if (targetAttacker && targetAttacker->active) {
      // Attacking logic
      float distStr = Vector3Distance(position, targetAttacker->position);
      float dx = targetAttacker->position.x - position.x;
      float dz = targetAttacker->position.z - position.z;
      float targetAngle = atan2f(dz, dx) * RAD2DEG;

      // We want to broadside them, so steer such that they are at ~90 degrees
      // from our rotation
      float perfectBroadsideAngle = targetAngle + 90.0f;

      float angleDiff = perfectBroadsideAngle - rotation;
      while (angleDiff > 180.0f)
        angleDiff -= 360.0f;
      while (angleDiff < -180.0f)
        angleDiff += 360.0f;

      if (angleDiff > 5.0f)
        rotation += turnSpeed * dt;
      else if (angleDiff < -5.0f)
        rotation -= turnSpeed * dt;

      speed += acceleration * dt;

      // Fire broadsides if roughly perpendicular
      if (fabs(angleDiff) < 20.0f && distStr < 400.0f && cooldown <= 0) {
        cooldown = maxCooldown;
        Vector3 dirStar = {cosf((rotation + 90.0f) * DEG2RAD), 0.0f,
                           sinf((rotation + 90.0f) * DEG2RAD)};
        Vector3 forwardDir = {cosf(rotation * DEG2RAD), 0.0f,
                              sinf(rotation * DEG2RAD)};
        Vector3 projVelStar = {dirStar.x * 400.0f + forwardDir.x * speed, 0.0f,
                               dirStar.z * 400.0f + forwardDir.z * speed};
        Game::GetInstance()->SpawnProjectile({position.x, 10.0f, position.z},
                                             projVelStar, damage, false, this);

        Vector3 dirPort = {cosf((rotation - 90.0f) * DEG2RAD), 0.0f,
                           sinf((rotation - 90.0f) * DEG2RAD)};
        Vector3 projVelPort = {dirPort.x * 400.0f + forwardDir.x * speed, 0.0f,
                               dirPort.z * 400.0f + forwardDir.z * speed};
        Game::GetInstance()->SpawnProjectile({position.x, 10.0f, position.z},
                                             projVelPort, damage, false, this);
      }

      // If too far, stop chasing
      if (distStr > 1500.0f) {
        isWandering = true;
        targetAttacker = nullptr;
      }
    } else {
      // Target was destroyed or ran away, go back to wander
      isWandering = true;
      targetAttacker = nullptr;
    }
  }

  // Localized Wind Calculation
  Vector2 localWindDir = Game::GetInstance()->windDirection;
  float localWindStr = Game::GetInstance()->windStrength;
  float closestDist = 999999.0f;
  for (auto &wz : Game::GetInstance()->windZones) {
    float dx = position.x - wz.pos.x;
    float dz = position.z - wz.pos.z;
    float d = sqrtf(dx * dx + dz * dz);
    if (d < wz.radius && d < closestDist) {
      closestDist = d;
      localWindDir = wz.direction;
      localWindStr = wz.strength;
    }
  }

  // Apply Wind affecting speed limit natively
  float rotRad = rotation * DEG2RAD;
  Vector2 shipDir = {cosf(rotRad), sinf(rotRad)};
  float windDot = Vector2DotProduct(shipDir, localWindDir);

  float currentMaxSpeed = maxSpeed;
  if (speed > 0) {
    currentMaxSpeed += maxSpeed * 0.5f * windDot * localWindStr;
    speed += (windDot * localWindStr * 60.0f) * dt;
  }

  if (speed > currentMaxSpeed)
    speed = currentMaxSpeed;
  if (speed < -currentMaxSpeed / 2)
    speed = -currentMaxSpeed / 2;

  position.x += shipDir.x * speed * dt;
  position.z += shipDir.y * speed * dt;

  // Island Collision (Ports support)
  for (auto &island : Game::GetInstance()->islands) {
    float dx = position.x - island.position.x;
    float dz = position.z - island.position.z;
    float dist = sqrtf(dx * dx + dz * dz) + radius;

    // AI Ships are forbidden from entering ANY island bay/inner radius
    if (!isPlayer && dist < island.radius + 50.0f) {
      float push = (island.radius + 50.0f) - dist;
      position.x += (dx / sqrtf(dx * dx + dz * dz)) * push;
      position.z += (dz / sqrtf(dx * dx + dz * dz)) * push;
      speed *= 0.5f;

      // Force AI to turn away from the island
      if (isWandering) {
        // Pick a new target immediately to avoid getting stuck
        targetPosition.x =
            position.x + (dx / sqrtf(dx * dx + dz * dz)) * 500.0f;
        targetPosition.z =
            position.z + (dz / sqrtf(dx * dx + dz * dz)) * 500.0f;
      } else {
        // If attacking, override rotation to steer away
        rotation += turnSpeed * dt * 2.0f;
      }
      continue;
    }

    // Player Check if we are inside the outer ring
    if (isPlayer && dist > island.innerRadius && dist < island.radius) {

      float angleToShip = atan2f(dz, dx) * RAD2DEG;

      bool inAnyOpening = false;
      for (float openingAngle : island.portOpeningAngles) {
        float df = angleToShip - openingAngle;
        while (df > 180.0f)
          df -= 360.0f;
        while (df < -180.0f)
          df += 360.0f;

        if (fabs(df) < island.portOpeningWidth / 2.0f) {
          inAnyOpening = true;
          break;
        }
      }

      // If we are NOT in the opening gap, we hit the wall
      if (!inAnyOpening) {
        // Determine if we should be pushed in or out depending on where we are
        // closer to
        float distToInner = fabs(dist - island.innerRadius);
        float distToOuter = fabs(dist - island.radius);

        if (distToInner < distToOuter) {
          // Push into the center (port)
          float push = island.innerRadius - dist;
          position.x += (dx / sqrtf(dx * dx + dz * dz)) * push;
          position.z += (dz / sqrtf(dx * dx + dz * dz)) * push;
        } else {
          // Push out to sea
          float push = island.radius - dist;
          position.x += (dx / sqrtf(dx * dx + dz * dz)) * push;
          position.z += (dz / sqrtf(dx * dx + dz * dz)) * push;
        }
        speed *= 0.5f;
      }
    }

    // Town menu only triggers if deep inside the port (center)
    if (isPlayer && dist < island.innerRadius &&
        Game::GetInstance()->state == GameState::PLAYING &&
        Game::GetInstance()->menuCooldownTimer <= 0) {
      Game::GetInstance()->state = island.isShipwright
                                       ? GameState::SHIPWRIGHT_MENU
                                       : GameState::TOWN_MENU;
      Game::GetInstance()->parkedIsland = &island;
      speed = 0.0f;
    }
  }

  // Ship to Ship Collisions
  for (auto &other : Game::GetInstance()->ships) {
    if (!other.active || &other == this)
      continue;
    float dx = position.x - other.position.x;
    float dz = position.z - other.position.z;
    float dist = sqrtf(dx * dx + dz * dz);
    if (dist < radius + other.radius) {
      // Push away
      float overlap = (radius + other.radius) - dist;
      float px = (dx / dist) * overlap * 0.5f;
      float pz = (dz / dist) * overlap * 0.5f;

      position.x += px;
      position.z += pz;
      other.position.x -= px;
      other.position.z -= pz;

      speed *= 0.8f;

      // Deal collision damage
      TakeDamage(50.0f * dt, &other);
      other.TakeDamage(50.0f * dt, this);

      if (isPlayer && hp <= 0) {
        Game::GetInstance()->state = GameState::DEAD;
      } else if (other.isPlayer && other.hp <= 0) {
        Game::GetInstance()->state = GameState::DEAD;
      }
    }
  }
}

void Ship::Draw() {
  if (!active)
    return;

  // Target indicator removed for keyboard-only mode

  rlPushMatrix();
  rlTranslatef(position.x, position.y, position.z);
  rlRotatef(-rotation, 0.0f, 1.0f, 0.0f); // Inverted to match CW minimap logic

  // Hull (Body)
  float hullLen = radius * 2.0f;
  DrawCube({0, 0, 0}, hullLen, radius, radius * 1.5f, color);
  DrawCubeWires({0, 0, 0}, hullLen, radius, radius * 1.5f, DARKGRAY);

  // Bow (Front - Pointed)
  float bowLen = radius * 1.2f;
  Vector3 p1 = {hullLen / 2, radius / 2, 0};
  Vector3 p2 = {hullLen / 2 + bowLen, 0, 0};
  Vector3 p3 = {hullLen / 2, -radius / 2, 0};
  DrawTriangle3D(p1, p2, p3, color); // Top tip

  // Stern (Back - Slightly narrower or flat with trim)
  DrawCube({-hullLen / 2 - radius * 0.2f, radius * 0.2f, 0}, radius * 0.4f,
           radius * 0.6f, radius * 1.2f, DARKBROWN);
  // Masts & Sails
  int numMasts = 1;
  if (type == ShipClass::BRIGANTINE)
    numMasts = 2;
  if (type == ShipClass::GALLEON)
    numMasts = 3;

  for (int i = 0; i < numMasts; i++) {
    float xPos = 0;
    if (numMasts == 2)
      xPos = (i == 0) ? radius * 0.5f : -radius * 0.5f;
    if (numMasts == 3)
      xPos = (i - 1) * radius * 0.7f;

    // Mast
    DrawCube({xPos, radius * 1.5f, 0}, 2.0f, radius * 3.0f, 2.0f, DARKBROWN);

    // Sail (Raylib white)
    float sailWidth = radius * 1.2f;
    float sailHeight = radius * 1.8f;
    DrawCube({xPos, radius * 2.0f, 0}, 2.0f, sailHeight, sailWidth, RAYWHITE);
  }

  // Draw Decorative Cannons
  for (int i = 0; i < 3; i++) {
    float zOffset = (radius * 0.7f);
    float xOffset = (radius * 0.8f) - (i * radius * 0.8f);
    // Port
    DrawCube({xOffset, radius * 0.2f, zOffset}, radius * 0.4f, radius * 0.3f,
             radius * 0.8f, BLACK);
    // Starboard
    DrawCube({xOffset, radius * 0.2f, -zOffset}, radius * 0.4f, radius * 0.3f,
             radius * 0.8f, BLACK);
  }

  rlPopMatrix();
}
