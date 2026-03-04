#include "Game.hpp"
#include "GameConfig.hpp"
#include "raygui.h"
#include <math.h>
#include <raymath.h>
#include <stdlib.h>

Game *Game::instance = nullptr;
int Entity::nextId = 0;
Game *Game::GetInstance() {
  if (instance == nullptr) {
    instance = new Game();
  }
  return instance;
}

void Game::Init() {
  camera.position = {-200.0f, 300.0f, -200.0f};
  camera.target = {0.0f, 0.0f, 0.0f};
  camera.up = {0.0f, 1.0f, 0.0f};
  camera.fovy = 35.0f; // Alternatively orthographic
  camera.projection = CAMERA_PERSPECTIVE;

  state = GameState::MENU;
  showFullMap = false;
  cameraAngle = {45.0f * (PI / 180.0f), 0.6f}; // Fixed Isometric
  cameraDistance = 1200.0f;                    // Zoomed out
  selectedClass = ShipClass::SLOOP;
  selectedColor = {0, 121, 241, 255}; // BLUE

  masterVolume = 0.5f;
  soundEnabled = true;

  keyUp = KEY_UP;
  keyDown = KEY_DOWN;
  keyLeft = KEY_LEFT;
  keyRight = KEY_RIGHT;
  keyFire = KEY_SPACE;
  keyMap = KEY_P;
  keyInteract = KEY_E;
  remappingKey = 0;

  fishingState = FishingState::INACTIVE;
  activeFishingZone = nullptr;
  fishingTimer = 0.0f;
  fishingQtePos = 0.0f;
  fishingQteTargetStart = 0.0f;
  fishingQteWidth = 0.0f;
  fishingQteDir = 1;
  fishingResultMsg = "";
  // Fishing zones will be spawned AFTER islands

  windDirection = Vector2Normalize({1.0f, 0.5f});
  windStrength = 0.8f;
  targetWindDirection = windDirection;
  targetWindStrength = windStrength;
  windChangeTimer = 10.0f;

  for (int i = 0; i < 500; i++) {
    windParticles.push_back(
        {{float(rand() % 40000 - 20000), 5.0f, float(rand() % 40000 - 20000)},
         float(rand() % 100) / 100.0f});
  }

  parkedIsland = nullptr;
  menuCooldownTimer = 0.0f;

  // Starter / Important Merchant Islands (distinct mark later)
  islands.push_back(Island({2500, 0, 2500}, 300.0f, false, true));
  islands.push_back(Island({-2400, 0, 2200}, 250.0f, false, true));
  islands.push_back(
      Island({1800, 0, -2500}, 100.0f, false, false, false, true)); // Fisherman

  // Shipwright Island (Expert Upgrades)
  islands.push_back(Island({0.0f, 0, -3500.0f}, 250.0f, false, false, true));

  // Normal Islands
  islands.push_back(Island({-1600, 0, -1300}, 350.0f, false, false));
  islands.push_back(Island({2000, 0, -500}, 400.0f, false, false));

  // --- CAPITAL CITY NETWORK ---
  // Create a central hub at (0, 0, 0) consisting of 4 large islands forming
  // river channels
  float capOffset = 450.0f; // Distance from center
  float capRadius = 350.0f; // Size of the capital islands
  // The 4 main landmasses of the capital (now solid blocks)
  islands.push_back(Island({capOffset, 0, capOffset}, capRadius, false, false,
                           false, false, false, true));
  islands.push_back(Island({-capOffset, 0, capOffset}, capRadius, false, false,
                           false, false, false, true));
  islands.push_back(Island({capOffset, 0, -capOffset}, capRadius, false, false,
                           false, false, false, true));
  islands.push_back(Island({-capOffset, 0, -capOffset}, capRadius, false, false,
                           false, false, false, true));

  // The Merchant Platforms in the river channels between the islands
  // 1. General Merchant (North channel)
  islands.push_back(
      Island({0.0f, 0, -capOffset}, 60.0f, false, true, false, false, true));
  // 2. Shipwright (South channel)
  islands.push_back(
      Island({0.0f, 0, capOffset}, 80.0f, false, false, true, false, true));
  // 3. Fisherman (East channel)
  islands.push_back(
      Island({capOffset, 0, 0.0f}, 50.0f, false, false, false, true, true));

  // Expand Map
  for (int i = 0; i < 40; i++) {
    bool isMerch = (rand() % 10 == 0);           // 10% chance to be merchant
    bool isFish = (!isMerch && rand() % 8 == 0); // ~12% chance to be fisherman

    // Check distance so they aren't completely on top of each other
    bool validPos = false;
    Vector3 testPos;
    float testRadius = isFish ? 100.0f : (200.0f + rand() % 400);
    int attempts = 0;
    while (!validPos && attempts < 50) {
      testPos = {float(rand() % 38000 - 19000), 0,
                 float(rand() % 38000 - 19000)};
      validPos = true;
      for (auto &existingIsland : islands) {
        float dx = testPos.x - existingIsland.position.x;
        float dz = testPos.z - existingIsland.position.z;
        float dist = sqrtf(dx * dx + dz * dz);
        if (dist < existingIsland.radius + testRadius + 800.0f) {
          // Ignore distance check if it's a tiny fish island spawning next to
          // something else? Actually, the user asked for them to not spawn
          // close *unless* they are tiny.
          if (existingIsland.isFisherman && isFish) {
            validPos = false; // Don't clump fish islands together
            break;
          } else if (!isFish &&
                     dist < existingIsland.radius + testRadius + 1500.0f) {
            validPos = false;
            break;
          }
        }
      }
      attempts++;
    }

    islands.push_back(
        Island(testPos, testRadius, false, isMerch, false, isFish));
  }

  // Spawn Fishing Zones clustered around Fisherman Islands
  fishingZones.clear();
  std::vector<Island *> fishermanIslands;
  for (auto &island : islands) {
    if (island.isFisherman) {
      fishermanIslands.push_back(&island);
    }
  }

  for (int i = 0; i < 60; i++) {
    FishingZone fz;
    fz.radius = 70.0f;                 // Smaller zones
    fz.fishRemaining = 3 + rand() % 3; // 3 to 5

    bool validPos = false;
    int fAttempts = 0;
    while (!validPos && fAttempts < 50) {
      if (!fishermanIslands.empty() && rand() % 100 < 75) {
        Island *target = fishermanIslands[rand() % fishermanIslands.size()];
        float angle = (rand() % 360) * DEG2RAD;
        // Spawn right outside the island
        float dist = target->radius + 150.0f + (rand() % 350);
        fz.position = {target->position.x + cosf(angle) * dist, 0.0f,
                       target->position.z + sinf(angle) * dist};
      } else {
        fz.position = {float(rand() % 38000 - 19000), 0.0f,
                       float(rand() % 38000 - 19000)};
      }
      validPos = true;
      for (const auto &existing : fishingZones) {
        float dx = fz.position.x - existing.position.x;
        float dz = fz.position.z - existing.position.z;
        if (sqrtf(dx * dx + dz * dz) < fz.radius + existing.radius) {
          validPos = false;
          break;
        }
      }
      fAttempts++;
    }
    fishingZones.push_back(fz);
  }

  // Load custom 3D models from assets
  shipSloopModel = LoadModel("assets/sloup.glb");

  // Use Point filtering (Nearest-Neighbor) for palette-based textures to stop
  // color bleeding/pixelation
  for (int i = 0; i < shipSloopModel.materialCount; i++) {
    SetTextureFilter(
        shipSloopModel.materials[i].maps[MATERIAL_MAP_DIFFUSE].texture,
        TEXTURE_FILTER_POINT);
  }

  for (int i = 0; i < 80; i++) {
    ships.push_back(
        Ship({float(rand() % 38000 - 19000), 0, float(rand() % 38000 - 19000)},
             false, (ShipClass)(rand() % 3), MAROON));
  }
}

void Game::SpawnPlayer() {
  for (size_t i = 0; i < ships.size(); i++) {
    if (ships[i].isPlayer) {
      ships.erase(ships.begin() + i);
      break;
    }
  }
  ships.insert(ships.begin(), Ship({2500.0f, 0.0f, 2500.0f}, true,
                                   selectedClass, selectedColor));
  ships[0].rotation = 270.0f;               // Face North (Up on map)
  ships[0].gold = GameConfig::StartingGold; // Starting Gold
  state = GameState::PLAYING;
  parkedIsland = nullptr;
}

void Game::SpawnLoot(Vector3 pos) {
  int dropCount = 3 + rand() % 3;
  for (int i = 0; i < dropCount; ++i) {
    LootType t = (LootType)(rand() % 5);
    int amt = 10 + rand() % 40;

    Vector3 offset = {pos.x + (rand() % 60 - 30), 0.0f,
                      pos.z + (rand() % 60 - 30)};
    lootDrops.push_back(Loot(offset, t, amt));
  }
}

void Game::SpawnProjectile(Vector3 pos, Vector3 velocity, float damage,
                           bool isPlayer, Ship *owner) {
  projectiles.push_back(Projectile(pos, velocity, damage, isPlayer, owner));
}

void Game::Update(float dt) {
  if (menuCooldownTimer > 0)
    menuCooldownTimer -= dt;

  if (state == GameState::PLAYING || state == GameState::FULL_MAP) {
    Ship *playerPtr = nullptr;
    for (auto &ship : ships) {
      ship.Update(dt);
      if (ship.isPlayer)
        playerPtr = &ship;
    }

    // Dynamic Wind Interpolation (Slower changes)
    windChangeTimer -= dt;
    if (windChangeTimer <= 0) {
      windChangeTimer = 60.0f + (rand() % 60); // Much slower
      targetWindDirection = Vector2Normalize(
          {float(rand() % 200 - 100), float(rand() % 200 - 100)});
      targetWindStrength = GameConfig::BaseWindStrengthMultiplier +
                           (float(rand() % 100) / 100.0f) *
                               GameConfig::MaxWindStrengthMultiplier;
    }

    windDirection.x += (targetWindDirection.x - windDirection.x) * dt * 0.1f;
    windDirection.y += (targetWindDirection.y - windDirection.y) * dt * 0.1f;
    windDirection = Vector2Normalize(windDirection);
    windStrength += (targetWindStrength - windStrength) * dt * 0.1f;

    // Wind Particles Update
    for (auto &wp : windParticles) {
      wp.pos.x += windDirection.x * (windStrength * 200.0f) * dt;
      wp.pos.z += windDirection.y * (windStrength * 200.0f) * dt;
      wp.life -= dt * 0.1f;
      if (wp.life <= 0) {
        wp.life = 0.5f + float(rand() % 50) / 100.0f;
        if (playerPtr) {
          // Spawn behind player relative to wind to flow over them
          wp.pos.x = playerPtr->position.x - windDirection.x * 1500.0f +
                     float(rand() % 3000 - 1500);
          wp.pos.z = playerPtr->position.z - windDirection.y * 1500.0f +
                     float(rand() % 3000 - 1500);
        }
      }
    }

    if (playerPtr) {
      if (playerPtr->position.x > 20000 || playerPtr->position.x < -20000 ||
          playerPtr->position.z > 20000 || playerPtr->position.z < -20000) {
        playerPtr->TakeDamage(10.0f * dt, nullptr);
      }

      // Diplomatic quest zones
      bool inZoneThisFrame = false;
      for (size_t i = 0; i < activeQuests.size();) {
        auto &q = activeQuests[i];
        if (q.type == QuestType::DIPLOMATIC) {
          float dx = playerPtr->position.x - q.targetLocation.x;
          float dz = playerPtr->position.z - q.targetLocation.z;
          if (sqrtf(dx * dx + dz * dz) < 1000.0f) {
            inZoneThisFrame = true;
            q.timer += dt;
            int secondsLeft = 30 - (int)q.timer;
            if (secondsLeft < 0)
              secondsLeft = 0;
            q.description = TextFormat("Maintenir la zone (%ds)", secondsLeft);
            if (q.timer >= 30.0f) {
              playerPtr->gold += q.rewardGold;
              activeQuests.erase(activeQuests.begin() + i);
              inZoneThisFrame = false; // Quest finished, drop aggro
              continue;
            }
          } else {
            q.timer = 0.0f; // Reset timer if you leave
            q.description = "Rejoindre et rester 30s";
          }
        }
        i++;
      }

      // Global Aggro Logic for Diplomatic Quests
      static bool wasInZone = false;
      if (inZoneThisFrame && !wasInZone) {
        // Just entered zone, aggro everything
        for (auto &ship : ships) {
          if (!ship.isPlayer) {
            ship.isWandering = false;
            ship.targetAttacker = playerPtr;
          }
        }
      } else if (!inZoneThisFrame && wasInZone) {
        // Just left zone or quest finished, drop aggro (unless legitimately
        // fighting? keep simple for now)
        for (auto &ship : ships) {
          if (!ship.isPlayer) {
            ship.isWandering = true;
            ship.targetAttacker = nullptr;
          }
        }
      }
      wasInZone = inZoneThisFrame;
      // Fishing Minigame Logic
      activeFishingZone = nullptr;
      for (auto &fz : fishingZones) {
        if (fz.fishRemaining <= 0)
          continue;
        float dx = playerPtr->position.x - fz.position.x;
        float dz = playerPtr->position.z - fz.position.z;
        if (sqrtf(dx * dx + dz * dz) < fz.radius) {
          activeFishingZone = &fz;
          break;
        }
      }

      if (activeFishingZone) {
        if (fishingState == FishingState::INACTIVE) {
          if ((IsMouseButtonPressed(MOUSE_LEFT_BUTTON) ||
               IsKeyPressed(keyInteract)) &&
              playerPtr->speed < 10.0f) {
            fishingState = FishingState::WAITING_FOR_BITE;
            fishingTimer = 1.0f + (rand() % 30) / 10.0f; // 1.0 to 4.0s
            fishingResultMsg = "";
          }
        } else if (fishingState == FishingState::WAITING_FOR_BITE) {
          fishingTimer -= dt;
          if (fishingTimer <= 0) {
            fishingState = FishingState::QTE;
            fishingQtePos = 0.0f;
            fishingQteDir = 1;
            fishingQteWidth = 0.2f + (rand() % 20) / 100.0f; // 0.2 to 0.4
            fishingQteTargetStart = (rand() % 60) / 100.0f;  // 0.0 to 0.6
          }
        } else if (fishingState == FishingState::QTE) {
          fishingQtePos += fishingQteDir * 1.5f * dt; // speed
          if (fishingQtePos > 1.0f) {
            fishingQtePos = 1.0f;
            fishingQteDir = -1;
          }
          if (fishingQtePos < 0.0f) {
            fishingQtePos = 0.0f;
            fishingQteDir = 1;
          }

          if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON) ||
              IsKeyPressed(keyInteract)) {
            if (fishingQtePos >= fishingQteTargetStart &&
                fishingQtePos <= fishingQteTargetStart + fishingQteWidth) {
              playerPtr->fish++;
              activeFishingZone->fishRemaining--;
              fishingResultMsg = "POISSON ATTRAPE !";
            } else {
              fishingResultMsg = "RATE !";
            }
            fishingState = FishingState::RESULT;
            fishingTimer = 2.0f;
          }
        } else if (fishingState == FishingState::RESULT) {
          fishingTimer -= dt;
          if (fishingTimer <= 0) {
            fishingState = FishingState::INACTIVE;
          }
        }
      } else {
        fishingState = FishingState::INACTIVE;
      }
    }

    for (auto &island : islands)
      island.Update(dt);
    for (auto &proj : projectiles)
      proj.Update(dt);
    for (auto &loot : lootDrops)
      loot.Update(dt);

    for (auto &proj : projectiles) {
      if (!proj.active)
        continue;
      for (auto &ship : ships) {
        if (!ship.active)
          continue;
        if (proj.isPlayerOwned == ship.isPlayer)
          continue;

        float dx = proj.position.x - ship.position.x;
        float dz = proj.position.z - ship.position.z;
        if (sqrtf(dx * dx + dz * dz) < proj.radius + ship.radius) {
          ship.TakeDamage(proj.damage, proj.owner);
          proj.active = false;

          if (ship.isPlayer && ship.hp <= 0) {
            state = GameState::DEAD;
          } else if (!ship.isPlayer && ship.hp <= 0) {
            SpawnLoot(ship.position);
            for (auto &q : activeQuests) {
              if (q.type == QuestType::MILITARY && q.targetShipId == ship.id) {
                q.stage = 1;
              }
            }
          }
          break;
        }
      }
      if (proj.active) {
        for (auto &island : islands) {
          float dx = proj.position.x - island.position.x;
          float dz = proj.position.z - island.position.z;
          if (sqrtf(dx * dx + dz * dz) < proj.radius + island.radius) {
            proj.active = false;
            break;
          }
        }
      }
    }

    if (playerPtr) {
      for (auto &loot : lootDrops) {
        if (!loot.active)
          continue;
        float dx = loot.position.x - playerPtr->position.x;
        float dz = loot.position.z - playerPtr->position.z;
        if (sqrtf(dx * dx + dz * dz) <
            loot.radius + playerPtr->radius + 15.0f) {
          loot.active = false;
          if (loot.type == LootType::LOOT_GOLD)
            playerPtr->gold += loot.amount;
          if (loot.type == LootType::LOOT_WOOD)
            playerPtr->wood += loot.amount;
          if (loot.type == LootType::LOOT_FOOD)
            playerPtr->food += loot.amount;
          if (loot.type == LootType::LOOT_WATER)
            playerPtr->water += loot.amount;
          if (loot.type == LootType::LOOT_AMMO) {
            playerPtr->ammo += loot.amount;
            if (playerPtr->ammo > playerPtr->maxAmmo)
              playerPtr->ammo = playerPtr->maxAmmo;
          }
        }
      }
    }

    if (IsKeyPressed(keyMap)) {
      if (state == GameState::PLAYING) {
        state = GameState::FULL_MAP;
        showFullMap = true;
      } else if (state == GameState::FULL_MAP) {
        state = GameState::PLAYING;
        showFullMap = false;
      }
    }

    float wheel = GetMouseWheelMove();
    cameraDistance -= wheel * 20.0f;
    if (cameraDistance < 100.0f)
      cameraDistance = 100.0f;
    if (cameraDistance > 2000.0f)
      cameraDistance = 2000.0f;

    if (playerPtr && playerPtr->active) {
      // Smooth Camera Interpolation (Lerp) to fix stuttering
      float lerpSpeed =
          5.0f * dt; // Adjust this value for snappier or looser follow

      camera.target.x += (playerPtr->position.x - camera.target.x) * lerpSpeed;
      camera.target.y += (playerPtr->position.y - camera.target.y) * lerpSpeed;
      camera.target.z += (playerPtr->position.z - camera.target.z) * lerpSpeed;

      Vector3 orbitOffset = {
          cosf(cameraAngle.x) * cameraDistance * cosf(cameraAngle.y),
          sinf(cameraAngle.y) * cameraDistance,
          sinf(cameraAngle.x) * cameraDistance * cosf(cameraAngle.y)};

      camera.position = {camera.target.x + orbitOffset.x,
                         camera.target.y + orbitOffset.y,
                         camera.target.z + orbitOffset.z};
    }

    if (playerPtr && !menuLocked && menuCooldownTimer <= 0) {
      for (auto &island : islands) {
        if (island.isGiant) {
          float dx = playerPtr->position.x - island.position.x;
          float dz = playerPtr->position.z - island.position.z;
          float dist = sqrtf(dx * dx + dz * dz);
          if (dist < island.innerRadius) {
            state = GameState::UPGRADE_MENU;
            lastMenuIsland = &island;
            menuLocked = true;
          }
        }
      }
    }

    if (menuLocked && lastMenuIsland && playerPtr) {
      float dx = playerPtr->position.x - lastMenuIsland->position.x;
      float dz = playerPtr->position.z - lastMenuIsland->position.z;
      float dist = sqrtf(dx * dx + dz * dz);
      if (dist > lastMenuIsland->radius + 50.0f ||
          (lastMenuIsland->isGiant &&
           dist > lastMenuIsland->innerRadius + 50.0f)) {
        menuLocked = false;
        lastMenuIsland = nullptr;
      }
    }

  } else if (state == GameState::MENU) {
    if (IsKeyPressed(KEY_ENTER))
      state = GameState::CUSTOMIZE;
  } else if (state == GameState::CUSTOMIZE) {
    if (IsKeyPressed(KEY_ENTER))
      SpawnPlayer();
  } else if (state == GameState::SETTINGS) {
    if (IsKeyPressed(KEY_ESCAPE) || IsKeyPressed(KEY_BACKSPACE)) {
      Ship *playerPtr = nullptr;
      for (auto &ship : ships)
        if (ship.isPlayer)
          playerPtr = &ship;
      state = playerPtr ? GameState::PLAYING : GameState::MENU;
    }
  }

  // Handle Quest Progress in Background (Real-time)
  Ship *playerPtr = nullptr;
  for (auto &ship : ships)
    if (ship.isPlayer)
      playerPtr = &ship;

  if (playerPtr &&
      (state == GameState::PLAYING || state == GameState::FULL_MAP)) {
    for (auto &q : activeQuests) {
      if (q.isCompleted)
        continue;

      if (q.type == QuestType::DIPLOMATIC) {
        for (auto &island : islands) {
          if (island.id == q.targetIslandId) {
            float dx = playerPtr->position.x - island.position.x;
            float dz = playerPtr->position.z - island.position.z;
            if (sqrtf(dx * dx + dz * dz) < island.radius + 150.0f) {
              q.isCompleted = true;
            }
            break;
          }
        }
      } else if (q.type == QuestType::MILITARY) {
        bool found = false;
        for (auto &ship : ships) {
          if (ship.id == q.targetShipId) {
            found = true;
            if (!ship.active || ship.hp <= 0) {
              q.isCompleted = true;
            }
            break;
          }
        }
        if (!found)
          q.isCompleted = true; // Target gone
      } else if (q.type == QuestType::FISHING) {
        if (q.timer > 0) {
          q.timer -= GetFrameTime();
          if (q.timer <= 0) {
            q.timer = 0;
            // Quest fails, handled later or user can't return it
          }
        }
      }
    }
  }
  // Handle state transitions that are not part of the main game loop
  if (state == GameState::TOWN_MENU || state == GameState::UPGRADE_MENU) {
    if (IsKeyPressed(keyMap) || IsKeyPressed(KEY_ESCAPE)) {
      showFullMap = false;
      state = GameState::PLAYING;
      parkedIsland = nullptr; // Ensure we clear the island reference
    }
  } else if (state == GameState::FULL_MAP) {
    if (IsKeyPressed(KEY_ESCAPE)) {
      showFullMap = false;
      state = GameState::PLAYING;
    }
  }
  if (state == GameState::DEAD) {
    if (IsKeyPressed(KEY_ENTER))
      state = GameState::CUSTOMIZE;
  }

  // Global check: if we are playing and NOT in a menu, ensure parkedIsland is
  // null
  if (state == GameState::PLAYING) {
    parkedIsland = nullptr;
  }
}

void Game::Draw() {
  Ship *playerPtr = nullptr;
  for (auto &ship : ships) {
    if (ship.isPlayer && ship.active) {
      playerPtr = &ship;
      break;
    }
  }

  // 1. Draw 3D World
  if (state != GameState::MENU && state != GameState::CUSTOMIZE) {
    BeginMode3D(camera);
    Color waterBase = {0, 80, 180, 255};
    // Removed DrawPlane: The massive 80000x80000 plane caused severe Z-fighting
    // The water background is now handled cleanly by ClearBackground() in
    // main.cpp.

    // Draw Ocean Lines/Grid for depth/movement perception (Increased density)
    // Draw at Y=0.0f, with water at -20.0f there's a huge gap to prevent
    // z-fighting
    for (int i = -20000; i <= 20000; i += 250) {
      DrawLine3D({(float)i, 0.0f, -20000.0f}, {(float)i, 0.0f, 20000.0f},
                 Fade(SKYBLUE, 0.3f));
      DrawLine3D({-20000.0f, 0.0f, (float)i}, {40000.0f, 0.0f, (float)i},
                 Fade(SKYBLUE, 0.3f));
    }

    for (auto &wp : windParticles) {
      if (Vector3Distance(camera.target, wp.pos) < 3000.0f) {
        DrawLine3D(wp.pos,
                   {wp.pos.x + windDirection.x * 40.0f, wp.pos.y,
                    wp.pos.z + windDirection.y * 40.0f},
                   Fade(WHITE, wp.life * 0.5f));
      }
    }

    // Fishing Zones
    for (auto &fz : fishingZones) {
      if (fz.fishRemaining > 0 &&
          Vector3Distance(camera.target, fz.position) < 4000.0f) {
        // Draw slightly above the 0.0f grid to prevent overlap
        DrawCylinder({fz.position.x, 0.5f, fz.position.z}, fz.radius, fz.radius,
                     1.0f, 16, Fade(SKYBLUE, 0.3f));
      }
    }

    for (auto &island : islands) {
      if (Vector3Distance(camera.target, island.position) < 4000.0f)
        island.Draw();
    }
    for (auto &loot : lootDrops) {
      if (Vector3Distance(camera.target, loot.position) < 3000.0f)
        loot.Draw();
    }
    for (auto &ship : ships) {
      if (Vector3Distance(camera.target, ship.position) < 5000.0f)
        ship.Draw();
    }
    for (auto &proj : projectiles)
      proj.Draw();
    EndMode3D();

    for (auto &ship : ships) {
      if (!ship.active || ship.isPlayer)
        continue;
      Vector2 sp = GetWorldToScreen(ship.position, camera);
      if (sp.x > 0 && sp.x < 1280 && sp.y > 0 && sp.y < 720) {
        float shp = ship.hp / ship.maxHp;
        DrawRectangle(sp.x - 20, sp.y - 40, 40, 5, RED);
        DrawRectangle(sp.x - 20, sp.y - 40, 40 * shp, 5, GREEN);
      }
    }

    // Fishing Minigame UI (2D overlay on player)
    if (activeFishingZone) {
      Vector2 screenPos = GetWorldToScreen(playerPtr->position, camera);
      if (fishingState == FishingState::INACTIVE) {
        DrawText("CLIQUE OU TOUCHE INTERAGIR POUR PECHER", screenPos.x - 140,
                 screenPos.y - 70, 20, YELLOW);
      } else if (fishingState == FishingState::WAITING_FOR_BITE) {
        DrawText("...", screenPos.x - 10, screenPos.y - 70, 20, LIGHTGRAY);
      } else if (fishingState == FishingState::QTE) {
        DrawRectangle(screenPos.x - 50, screenPos.y - 80, 100, 10, GRAY);
        DrawRectangle(screenPos.x - 50 + (fishingQteTargetStart * 100),
                      screenPos.y - 80, fishingQteWidth * 100, 10, RED);
        DrawRectangle(screenPos.x - 50 + (fishingQtePos * 100) - 2,
                      screenPos.y - 85, 4, 20, WHITE);
      } else if (fishingState == FishingState::RESULT) {
        DrawText(fishingResultMsg.c_str(),
                 screenPos.x - MeasureText(fishingResultMsg.c_str(), 20) / 2,
                 screenPos.y - 70, 20,
                 fishingResultMsg == "RATE !" ? RED : GREEN);
      }
    }
  }

  // 2. Main HUD
  if (playerPtr &&
      (state == GameState::PLAYING || state == GameState::TOWN_MENU ||
       state == GameState::UPGRADE_MENU || state == GameState::SETTINGS ||
       state == GameState::FULL_MAP)) {
    DrawText(
        TextFormat("BOULETS: %d / %d", playerPtr->ammo, playerPtr->maxAmmo), 20,
        20, 20, LIGHTGRAY);
    DrawText(TextFormat("Gold: %d", playerPtr->gold), 20, 50, 20, YELLOW);
    DrawText(TextFormat("Bois: %d", playerPtr->wood), 20, 80, 20, DARKBROWN);
    DrawText(TextFormat("Food: %d", playerPtr->food), 20, 110, 20, ORANGE);
    DrawText(TextFormat("Water: %d", playerPtr->water), 20, 140, 20, BLUE);

    if (GuiButton({1280 - 120, 720 - 50, 100, 30}, "SETTINGS"))
      state = GameState::SETTINGS;

    float hpPercent = playerPtr->hp / playerPtr->maxHp;
    const char *hpText =
        TextFormat("HP: %.0f / %.0f", playerPtr->hp, playerPtr->maxHp);
    DrawText(hpText, 1280 / 2 - MeasureText(hpText, 20) / 2, 720 - 60, 20,
             GREEN);
    DrawRectangle(1280 / 2 - 150, 720 - 30, 300, 15, RED);
    DrawRectangle(1280 / 2 - 150, 720 - 30, 300 * hpPercent, 15, GREEN);

    // Diplomatic Timer HUD
    for (const auto &q : activeQuests) {
      if (q.type == QuestType::DIPLOMATIC) {
        float dx = playerPtr->position.x - q.targetLocation.x;
        float dz = playerPtr->position.z - q.targetLocation.z;
        if (sqrtf(dx * dx + dz * dz) < 1000.0f) {
          int secondsLeft = 30 - (int)q.timer;
          if (secondsLeft < 0)
            secondsLeft = 0;
          const char *timerText =
              TextFormat("Maintenir la zone: %ds", secondsLeft);
          DrawText(timerText, 1280 / 2 - MeasureText(timerText, 30) / 2, 70, 30,
                   SKYBLUE);
        }
      }
    }

    // Wind UI
    DrawRectangle(20, 600, 150, 100, Fade(BLACK, 0.5f));
    DrawText("VENT", 30, 610, 20, WHITE);
    DrawText(TextFormat("Force: %.1f", windStrength), 30, 630, 20, LIGHTGRAY);
    Vector2 windCenter = {95, 670};
    DrawCircleV(windCenter, 20, DARKGRAY);
    DrawLineEx(windCenter,
               {windCenter.x + windDirection.x * 20.0f,
                windCenter.y + windDirection.y * 20.0f},
               3.0f, WHITE);

    // Minimap
    int mx = 1280 - 220;
    int my = 20;
    DrawRectangle(mx, my, 200, 200, Fade(BLACK, 0.8f));
    BeginScissorMode(mx, my, 200, 200);
    float mapScale = 200.0f / 8000.0f;
    Vector2 mapCenter = {mx + 100.0f, my + 100.0f};
    for (auto &island : islands) {
      float ix = mapCenter.x +
                 ((island.position.x - playerPtr->position.x) * mapScale);
      float iy = mapCenter.y +
                 ((island.position.z - playerPtr->position.z) * mapScale);
      Color ic = island.isMerchant
                     ? GOLD
                     : (island.isShipwright
                            ? PURPLE
                            : (island.isGiant ? LIGHTGRAY : DARKGREEN));

      if (island.isFisherman) {
        DrawRectangle(ix - (island.radius * mapScale),
                      iy - (island.radius * mapScale),
                      (island.radius * mapScale) * 2,
                      (island.radius * mapScale) * 2, {0, 228, 255, 255});
      } else {
        DrawCircle(ix, iy, island.radius * mapScale, ic);
      }
    }
    for (auto &ship : ships) {
      if (!ship.active)
        continue;
      float sx =
          mapCenter.x + ((ship.position.x - playerPtr->position.x) * mapScale);
      float sy =
          mapCenter.y + ((ship.position.z - playerPtr->position.z) * mapScale);
      DrawCircle(sx, sy, 4.0f, ship.isPlayer ? SKYBLUE : RED);
      // Direction Indicator
      Vector2 dir = {cosf(ship.rotation * DEG2RAD),
                     sinf(ship.rotation * DEG2RAD)};
      DrawLineV({sx, sy}, {sx + dir.x * 8.0f, sy + dir.y * 8.0f},
                ship.isPlayer ? WHITE : MAROON);
    }
    EndScissorMode();
    // Draw Quest Markers on Minimap
    for (auto &q : activeQuests) {
      Vector3 targetPos = {0, 0, 0};
      bool found = false;
      if (q.type == QuestType::MILITARY) {
        if (q.stage == 0) {
          for (auto &s : ships) {
            if (s.id == q.targetShipId) {
              targetPos = s.position;
              found = true;
              break;
            }
          }
        } else {
          for (auto &i : islands) {
            if (i.id == q.originIslandId) {
              targetPos = i.position;
              found = true;
              break;
            }
          }
        }
      } else if (q.type == QuestType::DIPLOMATIC) {
        targetPos = q.targetLocation;
        found = true;
      } else {
        for (auto &i : islands) {
          if (i.id == q.targetIslandId) {
            targetPos = i.position;
            found = true;
            break;
          }
        }
      }

      if (found) {
        float qx =
            mapCenter.x + ((targetPos.x - playerPtr->position.x) * mapScale);
        float qy =
            mapCenter.y + ((targetPos.z - playerPtr->position.z) * mapScale);
        if (qx > mx && qx < mx + 200 && qy > my && qy < my + 200) {
          DrawCircle(qx, qy, 4, YELLOW);
        }
      }
    }
    DrawRectangleLines(mx, my, 200, 200, RAYWHITE);

    // Minimap Compass (North Indicator)
    int cx = mx + 200 - 30;
    int cy = my + 30;
    DrawCircle(cx, cy, 15, Fade(BLACK, 0.6f));
    DrawCircleLines(cx, cy, 15, RAYWHITE);
    DrawLine(cx, cy - 12, cx, cy + 12, RED); // N-S line
    DrawText("N", cx - 4, cy - 25, 10, RAYWHITE);

    if (IsKeyDown(KEY_TAB)) {
      DrawRectangle(1280 / 2 - 350, 720 / 2 - 250, 700, 500, Fade(BLACK, 0.9f));
      DrawText("INVENTAIRE", 1280 / 2 - 330, 720 / 2 - 220, 30, SKYBLUE);
      int resY = 720 / 2 - 160;
      DrawText(TextFormat("OR: %d", playerPtr->gold), 1280 / 2 - 330, resY, 20,
               YELLOW);
      DrawText(TextFormat("BOIS: %d", playerPtr->wood), 1280 / 2 - 330,
               resY + 30, 20, DARKBROWN);
      DrawText(TextFormat("EAU: %d", playerPtr->water), 1280 / 2 - 330,
               resY + 60, 20, BLUE);
      DrawText(TextFormat("BOULETS: %d", playerPtr->ammo), 1280 / 2 - 330,
               resY + 90, 20, LIGHTGRAY);
      DrawText(TextFormat("NOURRITURE: %d", playerPtr->food), 1280 / 2 - 330,
               resY + 120, 20, ORANGE);
      DrawText(TextFormat("POISSONS: %d", playerPtr->fish), 1280 / 2 - 330,
               resY + 150, 20, SKYBLUE);

      DrawText("STATISTIQUES NAVIRE", 1280 / 2 - 330, resY + 200, 30, SKYBLUE);
      DrawText(TextFormat("VITESSE: %.0f", playerPtr->maxSpeed), 1280 / 2 - 330,
               resY + 230, 20, RAYWHITE);
      DrawText(TextFormat("HP MAX: %.0f", playerPtr->maxHp), 1280 / 2 - 330,
               resY + 260, 20, RAYWHITE);
      DrawText(TextFormat("DEGATS: %.0f", playerPtr->damage), 1280 / 2 - 330,
               resY + 290, 20, RAYWHITE);
      DrawText(TextFormat("CADENCE DE TIR: %.2f s", playerPtr->maxCooldown),
               1280 / 2 - 330, resY + 320, 20, RAYWHITE);
      DrawText(TextFormat("AMELIORATIONS: %d", playerPtr->upgradesPurchased),
               1280 / 2 - 330, resY + 350, 20, RAYWHITE);

      DrawText("QUETES EN COURS", 1280 / 2 + 30, 720 / 2 - 220, 30, YELLOW);
      if (activeQuests.empty())
        DrawText("Pas de quetes en cours", 1280 / 2 + 30, 720 / 2 - 20, 20,
                 GRAY);
      else {
        int startY = 720 / 2 - 160;
        for (auto &q : activeQuests) {
          DrawText(q.description.c_str(), 1280 / 2 + 30, startY, 18, RAYWHITE);
          DrawText(TextFormat("Recompense: %dg", q.rewardGold), 1280 / 2 + 30,
                   startY + 20, 18, GREEN);
          startY += 50;
        }
      }
    }
  }

  // 3. UI Overlays
  if (state == GameState::MENU) {
    DrawRectangle(0, 0, 1280, 720, Fade(BLACK, 0.5f));
    DrawText("KARTUGA CLONE", 1280 / 2 - MeasureText("KARTUGA CLONE", 60) / 2,
             200, 60, RAYWHITE);
    if (GuiButton({1280 / 2.0f - 100, 360, 200, 50}, "DEMARRER L'AVENTURE"))
      state = GameState::CUSTOMIZE;
    if (GuiButton({1280 / 2.0f - 100, 480, 200, 50}, "REGLAGES"))
      state = GameState::SETTINGS;
  } else if (state == GameState::CUSTOMIZE) {
    DrawRectangle(1280 / 2 - 300, 720 / 2 - 250, 600, 500, Fade(BLACK, 0.8f));
    DrawText("CUSTOMISER NAVIRE",
             1280 / 2 - MeasureText("CUSTOMISER NAVIRE", 40) / 2, 140, 40,
             RAYWHITE);

    // Class Selection
    if (GuiButton({1280 / 2.0f - 200, 220, 130, 40}, "SLOOP"))
      selectedClass = ShipClass::SLOOP;
    if (GuiButton({1280 / 2.0f - 65, 220, 130, 40}, "BRIGANTIN"))
      selectedClass = ShipClass::BRIGANTINE;
    if (GuiButton({1280 / 2.0f + 70, 220, 130, 40}, "GALION"))
      selectedClass = ShipClass::GALLEON;

    const char *classDesc = "1 Voile, maniable, lent.";
    if (selectedClass == ShipClass::BRIGANTINE)
      classDesc = "2 Voiles, equilibre.";
    if (selectedClass == ShipClass::GALLEON)
      classDesc = "3 Voiles, rapide, lourd.";
    DrawText(classDesc, 1280 / 2 - MeasureText(classDesc, 20) / 2, 280, 20,
             LIGHTGRAY);

    // Color Selection
    if (GuiButton({1280 / 2.0f - 150, 320, 90, 40}, "BLEU"))
      selectedColor = BLUE;
    if (GuiButton({1280 / 2.0f - 45, 320, 90, 40}, "VERT"))
      selectedColor = GREEN;
    if (GuiButton({1280 / 2.0f + 60, 320, 90, 40}, "ROUGE"))
      selectedColor = RED;

    DrawRectangle(1280 / 2 - 20, 380, 40, 40, selectedColor);

    if (GuiButton({1280 / 2.0f - 150, 500, 300, 50}, "PRENDRE LA MER !"))
      SpawnPlayer();
  } else if (state == GameState::SETTINGS) {
    DrawRectangle(1280 / 2 - 250, 720 / 2 - 250, 500, 500, Fade(BLACK, 0.9f));
    DrawText("REGLAGES", 1280 / 2 - 100, 140, 40, RAYWHITE);

    DrawText("VOLUME MASTER", 1280 / 2 - 200, 210, 20, LIGHTGRAY);
    GuiSlider({1280 / 2.0f - 200, 230, 400, 20}, "0.0", "1.0", &masterVolume,
              0.0f, 1.0f);
    SetMasterVolume(masterVolume);

    DrawText("SONS", 1280 / 2 - 200, 270, 20, LIGHTGRAY);
    if (GuiButton({1280 / 2.0f - 200, 290, 150, 35},
                  soundEnabled ? "SON: ON" : "SON: OFF")) {
      soundEnabled = !soundEnabled;
    }

    DrawText("TOUCHES (CLIQUEZ POUR CHANGER)", 1280 / 2 - 200, 350, 20,
             LIGHTGRAY);

    const char *upName = (remappingKey == 1) ? "PRESS ANY KEY..."
                                             : TextFormat("HAUT: %d", keyUp);
    if (GuiButton({1280 / 2.0f - 200, 380, 190, 30}, upName))
      remappingKey = 1;

    const char *downName = (remappingKey == 2) ? "PRESS ANY KEY..."
                                               : TextFormat("BAS: %d", keyDown);
    if (GuiButton({1280 / 2.0f + 10, 380, 190, 30}, downName))
      remappingKey = 2;

    const char *leftName = (remappingKey == 3)
                               ? "PRESS ANY KEY..."
                               : TextFormat("GAUCHE: %d", keyLeft);
    if (GuiButton({1280 / 2.0f - 200, 420, 190, 30}, leftName))
      remappingKey = 3;

    const char *rightName = (remappingKey == 4)
                                ? "PRESS ANY KEY..."
                                : TextFormat("DROITE: %d", keyRight);
    if (GuiButton({1280 / 2.0f + 10, 420, 190, 30}, rightName))
      remappingKey = 4;

    const char *fireName = (remappingKey == 5) ? "PRESS ANY KEY..."
                                               : TextFormat("TIR: %d", keyFire);
    if (GuiButton({1280 / 2.0f - 210, 460, 200, 30}, fireName))
      remappingKey = 5;

    const char *mapName = (remappingKey == 6) ? "PRESS ANY KEY..."
                                              : TextFormat("CARTE: %d", keyMap);
    if (GuiButton({1280 / 2.0f + 10, 460, 200, 30}, mapName))
      remappingKey = 6;

    const char *interactName =
        (remappingKey == 7) ? "PRESS ANY KEY..."
                            : TextFormat("INTERAGIR/PECHER: %d", keyInteract);
    if (GuiButton({1280 / 2.0f - 100, 500, 200, 30}, interactName))
      remappingKey = 7;

    if (remappingKey > 0) {
      int key = GetKeyPressed();
      if (key > 0) {
        if (remappingKey == 1)
          keyUp = key;
        if (remappingKey == 2)
          keyDown = key;
        if (remappingKey == 3)
          keyLeft = key;
        if (remappingKey == 4)
          keyRight = key;
        if (remappingKey == 5)
          keyFire = key;
        if (remappingKey == 6)
          keyMap = key;
        if (remappingKey == 7)
          keyInteract = key;
        remappingKey = 0;
      }
    }

    if (GuiButton({1280 / 2.0f - 100, 550, 200, 40}, "RETOUR")) {
      state = playerPtr ? GameState::PLAYING : GameState::MENU;
      remappingKey = 0;
    }
  } else if (state == GameState::TOWN_MENU && playerPtr) {
    DrawRectangle(1280 / 2 - 225, 720 / 2 - 270, 450, 540, Fade(BLACK, 0.85f));
    DrawText("ESC pour quitter", 1280 / 2 - 215, 720 / 2 - 260, 15, GRAY);
    DrawText("VILLE", 1280 / 2 - MeasureText("VILLE", 30) / 2, 120, 30,
             RAYWHITE);

    // Quests are no longer auto-completed here.

    // Quest Stage Buttons for Merchant Quests (One-way) - Moved up to avoid
    // overlap
    if (!activeQuests.empty() && parkedIsland) {
      bool canSell = false;
      for (const auto &q : activeQuests) {
        if (q.type == QuestType::MERCHANT &&
            parkedIsland->id == q.targetIslandId) {
          canSell = true;
          break;
        }
      }

      if (!canSell)
        GuiSetState(STATE_DISABLED);

      if (GuiButton({1280 / 2.0f - 210, 150, 420, 35},
                    "[!] VENDRE MARCHANDISES DE QUETE")) {
        for (size_t i = 0; i < activeQuests.size();) {
          if (activeQuests[i].type == QuestType::MERCHANT &&
              parkedIsland->id == activeQuests[i].targetIslandId) {
            playerPtr->gold += activeQuests[i].rewardGold;
            activeQuests.erase(activeQuests.begin() + i);
          } else {
            i++;
          }
        }
      }

      GuiSetState(STATE_NORMAL);

      bool canReturnMilitary = false;
      for (const auto &q : activeQuests) {
        if (q.type == QuestType::MILITARY && q.stage == 1 &&
            parkedIsland->id == q.originIslandId) {
          canReturnMilitary = true;
          break;
        }
      }

      if (!canReturnMilitary)
        GuiSetState(STATE_DISABLED);

      if (GuiButton({1280 / 2.0f - 210, 195, 420, 35},
                    "[!] RECLAMER RECOMPENSE MILITAIRE")) {
        for (size_t i = 0; i < activeQuests.size();) {
          if (activeQuests[i].type == QuestType::MILITARY &&
              activeQuests[i].stage == 1 &&
              parkedIsland->id == activeQuests[i].originIslandId) {
            playerPtr->gold += activeQuests[i].rewardGold;
            activeQuests.erase(activeQuests.begin() + i);
          } else {
            i++;
          }
        }
      }

      GuiSetState(STATE_NORMAL);
    }

    if (GuiButton({1280 / 2.0f - 150, 240, 300, 40},
                  TextFormat("REPARATIONS & MUNITIONS (%dg)",
                             GameConfig::RepairCost))) {
      if (playerPtr->gold >= GameConfig::RepairCost) {
        playerPtr->gold -= GameConfig::RepairCost;
        playerPtr->hp = playerPtr->maxHp;
        playerPtr->ammo = playerPtr->maxAmmo;
      }
    }
    if (parkedIsland && parkedIsland->isMerchant) {
      DrawText("MARCHAND", 1280 / 2 - 50, 295, 20, GOLD);
      if (GuiButton({1280 / 2.0f - 200, 325, 190, 35},
                    TextFormat("VENDRE 50 BOIS (%dg)",
                               GameConfig::SellBatchWoodGold))) {
        if (playerPtr->wood >= 50) {
          playerPtr->wood -= 50;
          playerPtr->gold += GameConfig::SellBatchWoodGold;
        }
      }
      if (GuiButton({1280 / 2.0f + 10, 325, 190, 35},
                    TextFormat("VENDRE 50 EAU (%dg)",
                               GameConfig::SellBatchWaterGold))) {
        if (playerPtr->water >= 50) {
          playerPtr->water -= 50;
          playerPtr->gold += GameConfig::SellBatchWaterGold;
        }
      }
      if (GuiButton({1280 / 2.0f - 200, 365, 400, 35},
                    TextFormat("VENDRE 50 NOURRITURE (%dg)",
                               GameConfig::SellBatchFoodGold))) {
        if (playerPtr->food >= 50) {
          playerPtr->food -= 50;
          playerPtr->gold += GameConfig::SellBatchFoodGold;
        }
      }

      DrawText("MISSIONS", 1280 / 2 - 50, 410, 20, YELLOW);
      // Merchant Quest
      if (GuiButton({1280 / 2.0f - 210, 440, 135, 35},
                    TextFormat("TRANSPORT (-%dg/+%dg)",
                               GameConfig::QuestMerchantCost,
                               GameConfig::QuestMerchantReward))) {
        if (playerPtr->gold >= GameConfig::QuestMerchantCost &&
            activeQuests.size() < 5) {
          int targetIdx = rand() % islands.size();
          while (islands[targetIdx].id == parkedIsland->id ||
                 islands[targetIdx].isShipwright) {
            targetIdx = rand() % islands.size();
          }
          playerPtr->gold -= GameConfig::QuestMerchantCost;
          Quest nq;
          nq.type = QuestType::MERCHANT;
          nq.originIslandId = parkedIsland->id;
          nq.targetIslandId = islands[targetIdx].id;
          nq.description = "Livrer marchandise au port";
          nq.rewardGold = GameConfig::QuestMerchantReward;
          nq.targetShipId = -1;
          nq.stage = 0;
          nq.isCompleted = false;
          activeQuests.push_back(nq);
        }
      }
      // Military Quest
      if (GuiButton({1280 / 2.0f - 65, 440, 140, 35},
                    TextFormat("MILITAIRE (-%dg/+%dg)",
                               GameConfig::QuestMilitaryCost,
                               GameConfig::QuestMilitaryReward))) {
        if (playerPtr->gold >= GameConfig::QuestMilitaryCost &&
            activeQuests.size() < 5 && ships.size() > 1) {
          int targetIdx = 1 + (rand() % (ships.size() - 1));
          playerPtr->gold -= GameConfig::QuestMilitaryCost;
          Quest nq;
          nq.type = QuestType::MILITARY;
          nq.originIslandId = parkedIsland->id;
          nq.targetShipId = ships[targetIdx].id;
          nq.targetIslandId = -1;
          nq.description = "Couler le navire et revenir";
          nq.rewardGold = GameConfig::QuestMilitaryReward;
          nq.stage = 0;
          nq.isCompleted = false;
          activeQuests.push_back(nq);
        }
      }
      // Diplomatic Quest
      if (GuiButton({1280 / 2.0f + 85, 440, 140, 35},
                    TextFormat("DIPLOMATIE (-%dg/+%dg)",
                               GameConfig::QuestDiplomaticCost,
                               GameConfig::QuestDiplomaticReward))) {
        if (playerPtr->gold >= GameConfig::QuestDiplomaticCost &&
            activeQuests.size() < 5) {
          playerPtr->gold -= GameConfig::QuestDiplomaticCost;
          Quest nq;
          nq.type = QuestType::DIPLOMATIC;
          nq.originIslandId = parkedIsland->id;
          nq.targetIslandId = -1;
          nq.targetLocation = {float(rand() % 38000 - 19000), 0.0f,
                               float(rand() % 38000 - 19000)};
          nq.timer = 0.0f;
          nq.description = "Maintenir la zone 30s";
          nq.rewardGold = GameConfig::QuestDiplomaticReward;
          nq.targetShipId = -1;
          nq.stage = 0;
          nq.isCompleted = false;
          activeQuests.push_back(nq);
        }
      }
    }

    if (parkedIsland && parkedIsland->isFisherman) {
      DrawText("PORT DE PECHE", 1280 / 2 - 80, 295, 20, SKYBLUE);
      bool hasFishingQuest = false;
      bool canReturnFishing = false;
      Quest *fq = nullptr;
      int qIdx = -1;
      for (size_t i = 0; i < activeQuests.size(); i++) {
        if (activeQuests[i].type == QuestType::FISHING) {
          hasFishingQuest = true;
          fq = &activeQuests[i];
          qIdx = i;
          if (parkedIsland->id == fq->originIslandId &&
              playerPtr->fish >= fq->targetAmount) {
            canReturnFishing = true;
          }
          break;
        }
      }

      if (canReturnFishing) {
        if (GuiButton(
                {1280 / 2.0f - 200, 340, 400, 40},
                TextFormat("RENDRE QUETE DE PECHE (+%dg)", fq->rewardGold))) {
          playerPtr->gold += fq->rewardGold;
          playerPtr->fish -= fq->targetAmount;
          activeQuests.erase(activeQuests.begin() + qIdx);
        }
      } else if (!hasFishingQuest && activeQuests.size() < 5) {
        if (GuiButton({1280 / 2.0f - 200, 340, 400, 40},
                      "NOUVELLE QUETE DE PECHE")) {
          Quest nq;
          nq.type = QuestType::FISHING;
          nq.originIslandId = parkedIsland->id;
          nq.targetIslandId = -1;
          nq.targetAmount = 3 + rand() % 8; // 3 to 10
          nq.currentAmount = 0;
          nq.timer = 180.0f; // 3 minutes
          nq.description = TextFormat("Ramener %d poissons", nq.targetAmount);
          nq.rewardGold = nq.targetAmount * 150; // Good payout for the effort
          nq.targetShipId = -1;
          nq.stage = 0;
          nq.isCompleted = false;
          activeQuests.push_back(nq);
        }
      } else if (hasFishingQuest) {
        DrawText(TextFormat("Objectif: %d / %d poissons", playerPtr->fish,
                            fq->targetAmount),
                 1280 / 2 - 130, 350, 20, LIGHTGRAY);
      }
    }

    if (GuiButton({1280 / 2.0f - 100, 650, 200, 40}, "QUITTER LE PORT")) {
      state = GameState::PLAYING;
      menuCooldownTimer = 15.0f;
    }
  } else if (state == GameState::UPGRADE_MENU && playerPtr) {
    DrawRectangle(1280 / 2 - 225, 720 / 2 - 200, 450, 380, Fade(BLACK, 0.85f));
    DrawText("ESC pour quitter", 1280 / 2 - 215, 720 / 2 - 190, 15, GRAY);
    DrawText("CHANTIER NAVAL", 1280 / 2 - 150, 180, 30, GOLD);
    DrawText(TextFormat("Or: %d  Bois: %d", playerPtr->gold, playerPtr->wood),
             1280 / 2 - 150, 220, 20, RAYWHITE);

    if (GuiButton({1280 / 2.0f - 200, 280, 400, 40},
                  TextFormat("UPGRADE VITESSE (%dg, %d Bois)",
                             GameConfig::UpgradeSpeedGold,
                             GameConfig::UpgradeSpeedWood))) {
      if (playerPtr->gold >= GameConfig::UpgradeSpeedGold &&
          playerPtr->wood >= GameConfig::UpgradeSpeedWood) {
        playerPtr->gold -= GameConfig::UpgradeSpeedGold;
        playerPtr->wood -= GameConfig::UpgradeSpeedWood;
        playerPtr->speedLevel++;
        playerPtr->upgradesPurchased++;
        playerPtr->maxSpeed *= 1.1f;
      }
    }
    if (GuiButton({1280 / 2.0f - 200, 340, 400, 40},
                  TextFormat("UPGRADE CADENCE (%dg, %d Bois)",
                             GameConfig::UpgradeFireRateGold,
                             GameConfig::UpgradeFireRateWood))) {
      if (playerPtr->gold >= GameConfig::UpgradeFireRateGold &&
          playerPtr->wood >= GameConfig::UpgradeFireRateWood) {
        playerPtr->gold -= GameConfig::UpgradeFireRateGold;
        playerPtr->wood -= GameConfig::UpgradeFireRateWood;
        playerPtr->fireRateLevel++;
        playerPtr->upgradesPurchased++;
        playerPtr->maxCooldown *= 0.8f;
      }
    }
    if (GuiButton({1280 / 2.0f - 100, 460, 200, 40}, "QUITTER")) {
      state = GameState::PLAYING;
      menuCooldownTimer = 15.0f;
    }
  } else if (state == GameState::SHIPWRIGHT_MENU && playerPtr) {
    DrawRectangle(1280 / 2 - 225, 720 / 2 - 200, 450, 380, Fade(BLACK, 0.85f));
    DrawText("ESC pour quitter", 1280 / 2 - 215, 720 / 2 - 190, 15, GRAY);
    DrawText("CHANTIER NAVAL EXPERT",
             1280 / 2 - MeasureText("CHANTIER NAVAL EXPERT", 30) / 2, 180, 30,
             GOLD);
    DrawText(TextFormat("Or: %d", playerPtr->gold), 1280 / 2 - 40, 230, 20,
             RAYWHITE);

    if (GuiButton({1280 / 2.0f - 200, 280, 400, 40},
                  TextFormat("VOILES SUPERIEURES (+Vitesse, 1000g)"))) {
      if (playerPtr->gold >= 1000) {
        playerPtr->gold -= 1000;
        playerPtr->upgradesPurchased++;
        playerPtr->maxSpeed *= 1.25f;
      }
    }
    if (GuiButton({1280 / 2.0f - 200, 340, 400, 40},
                  TextFormat("CANONS SUPPLEMENTAIRES (+Tir, 1500g)"))) {
      if (playerPtr->gold >= 1500) {
        playerPtr->gold -= 1500;
        playerPtr->upgradesPurchased++;
        playerPtr->extraCannons++;
      }
    }
    if (GuiButton({1280 / 2.0f - 200, 400, 400, 40},
                  TextFormat("RECHARGEMENT EXPERT (+Cadence, 1200g)"))) {
      if (playerPtr->gold >= 1200) {
        playerPtr->gold -= 1200;
        playerPtr->upgradesPurchased++;
        playerPtr->maxCooldown *= 0.6f;
      }
    }
    if (GuiButton({1280 / 2.0f - 100, 520, 200, 40}, "QUITTER")) {
      state = GameState::PLAYING;
      menuCooldownTimer = 15.0f;
    }
  } else if (state == GameState::FULL_MAP && playerPtr) {
    DrawRectangle(0, 0, 1280, 720, Fade(BLUE, 0.4f));
    DrawText("CARTE DU MONDE", 20, 20, 30, RAYWHITE);
    DrawRectangle(1280 / 2 - 300, 720 / 2 - 300, 600, 600, Fade(BLACK, 0.9f));

    float mapScale = 600.0f / 40000.0f;
    Vector2 mapCenter = {1280 / 2.0f, 720 / 2.0f};

    // Panning logic (Mouse Drag)
    static Vector2 mapOffset = {0, 0};
    if (IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
      Vector2 delta = GetMouseDelta();
      mapOffset.x += delta.x;
      mapOffset.y += delta.y;
    }

    // Right Click to Move (Full Map)
    if (IsMouseButtonPressed(MOUSE_RIGHT_BUTTON)) {
      Vector2 mousePos = GetMousePosition();
      // Check if clicked inside map area
      if (mousePos.x > 1280 / 2 - 300 && mousePos.x < 1280 / 2 + 300 &&
          mousePos.y > 720 / 2 - 300 && mousePos.y < 720 / 2 + 300) {
        float clickWorldX = (mousePos.x - mapCenter.x - mapOffset.x) / mapScale;
        float clickWorldZ = (mousePos.y - mapCenter.y - mapOffset.y) / mapScale;
        playerPtr->targetPosition = {clickWorldX, 0.0f, clickWorldZ};
        playerPtr->isWandering = false;
      }
    }

    if (IsKeyPressed(KEY_C)) {
      mapOffset.x = -playerPtr->position.x * mapScale;
      mapOffset.y = -playerPtr->position.z * mapScale;
    }

    DrawText("Clic Gauche: Glisser la carte", 1280 / 2 + 320, 720 / 2 - 280, 15,
             LIGHTGRAY);
    DrawText("[C] : Centrer sur le navire", 1280 / 2 + 320, 720 / 2 - 250, 15,
             LIGHTGRAY);

    // --- DRAW MAP BORDER AND LABELS ---
    DrawRectangleLines(1280 / 2 - 300, 720 / 2 - 300, 600, 600, RAYWHITE);
    float gridStep = 600.0f / 10.0f;

    // Draw Labels outside the map edge, taking offset into account
    // To ensure perfect alignment, we calculate the line position exactly like
    // the inner grid
    for (int i = 0; i <= 10; i++) {
      // --- X AXIS (Columns A-J) ---
      // 1. Where does this physical line fall on the screen?
      float screenLineX =
          (1280 / 2 - 300) + i * gridStep + fmodf(mapOffset.x, gridStep);

      // 2. What global map coordinate does this line represent?
      // We know we are `fmodf` pixels into a grid block.
      // We calculate the number of entire grid blocks we've bypassed in our
      // offset.
      float globalMapX = i * gridStep - mapOffset.x;
      int colIndex = (int)floorf(globalMapX / gridStep);

      // 3. We draw the label in the center of the column.
      // The column 'colIndex' spans from `screenLineX` to `screenLineX +
      // gridStep`
      float labelCenterX = screenLineX + (gridStep / 2.0f);

      if (colIndex >= 0 && colIndex < 10) {
        // Only draw if the center of this column is within the visual map
        // bounds (left and right edge)
        if (labelCenterX > (1280 / 2 - 300) &&
            labelCenterX < (1280 / 2 + 300)) {
          DrawText(TextFormat("%c", 'A' + colIndex), labelCenterX - 5,
                   720 / 2 - 325, 20, RAYWHITE);
        }
      }

      // --- Y AXIS (Rows 1-10) ---
      float screenLineY =
          (720 / 2 - 300) + i * gridStep + fmodf(mapOffset.y, gridStep);

      float globalMapY = i * gridStep - mapOffset.y;
      int rowIndex = (int)floorf(globalMapY / gridStep);

      float labelCenterY = screenLineY + (gridStep / 2.0f);

      if (rowIndex >= 0 && rowIndex < 10) {
        // Only draw if the center of this row is within visual map bounds (top
        // and bottom edge)
        if (labelCenterY > (720 / 2 - 300) && labelCenterY < (720 / 2 + 300)) {
          DrawText(TextFormat("%d", rowIndex + 1), 1280 / 2 - 330,
                   labelCenterY - 10, 20, RAYWHITE);
        }
      }
    }

    // --- DRAW MAP CONTENTS (Scissor Mode) ---
    BeginScissorMode(1280 / 2 - 300, 720 / 2 - 300, 600, 600);

    // Draw Grid Lines
    for (int i = 0; i <= 10; i++) {
      float linePosX =
          (1280 / 2 - 300) + i * gridStep + fmodf(mapOffset.x, gridStep);
      DrawLine(linePosX, 720 / 2 - 300, linePosX, 720 / 2 + 300,
               Fade(GRAY, 0.3f));
      float linePosY =
          (720 / 2 - 300) + i * gridStep + fmodf(mapOffset.y, gridStep);
      DrawLine(1280 / 2 - 300, linePosY, 1280 / 2 + 300, linePosY,
               Fade(GRAY, 0.3f));
    }
    for (auto &island : islands) {
      float ix = mapCenter.x + mapOffset.x + (island.position.x * mapScale);
      float iy = mapCenter.y + mapOffset.y + (island.position.z * mapScale);
      Color islandColor =
          island.isMerchant ? GOLD : (island.isShipwright ? PURPLE : DARKGREEN);

      if (island.isFisherman) {
        DrawRectangle(ix - (island.radius * mapScale),
                      iy - (island.radius * mapScale),
                      (island.radius * mapScale) * 2,
                      (island.radius * mapScale) * 2, {0, 228, 255, 255});
      } else {
        DrawCircle(ix, iy, island.radius * mapScale, islandColor);
      }
    }
    for (auto &ship : ships) {
      if (!ship.active)
        continue;
      float sx = mapCenter.x + mapOffset.x + (ship.position.x * mapScale);
      float sy = mapCenter.y + mapOffset.y + (ship.position.z * mapScale);
      DrawCircle(sx, sy, ship.isPlayer ? 8.0f : 3.0f,
                 ship.isPlayer ? SKYBLUE : RED);
      // Direction Indicator
      Vector2 dir = {cosf(ship.rotation * DEG2RAD),
                     sinf(ship.rotation * DEG2RAD)};
      DrawLineV({sx, sy}, {sx + dir.x * 12.0f, sy + dir.y * 12.0f},
                ship.isPlayer ? WHITE : MAROON);
    }

    // Quest Markers on Full Map
    for (auto &q : activeQuests) {
      Vector3 targetPos = {0, 0, 0};
      bool found = false;
      if (q.type == QuestType::MILITARY) {
        if (q.stage == 0) {
          for (auto &s : ships) {
            if (s.id == q.targetShipId) {
              targetPos = s.position;
              found = true;
              break;
            }
          }
        } else {
          for (auto &i : islands) {
            if (i.id == q.originIslandId) {
              targetPos = i.position;
              found = true;
              break;
            }
          }
        }
      } else if (q.type == QuestType::DIPLOMATIC) {
        targetPos = q.targetLocation;
        found = true;
      } else {
        for (auto &i : islands) {
          if (i.id == q.targetIslandId) {
            targetPos = i.position;
            found = true;
            break;
          }
        }
      }
      if (found) {
        float qx = mapCenter.x + mapOffset.x + (targetPos.x * mapScale);
        float qy = mapCenter.y + mapOffset.y + (targetPos.z * mapScale);
        DrawCircle(qx, qy, 6, YELLOW);
        DrawCircleLines(qx, qy, 10, YELLOW);

        // Calculate Grid coordinates (A-J, 1-10)
        int col = (int)floorf((targetPos.x + 20000.0f) / 4000.0f);
        int row = (int)floorf((targetPos.z + 20000.0f) / 4000.0f);
        if (col < 0)
          col = 0;
        if (col > 9)
          col = 9;
        if (row < 0)
          row = 0;
        if (row > 9)
          row = 9;

        char colChar = 'A' + col;
        int rowNum = row + 1;
        const char *labelText = TextFormat("RDV (%c%d)", colChar, rowNum);

        DrawText(labelText, qx - MeasureText(labelText, 10) / 2, qy + 12, 10,
                 YELLOW);
      }
    }

    EndScissorMode();
    DrawRectangleLines(1280 / 2 - 300, 720 / 2 - 300, 600, 600, RAYWHITE);
  } else if (state == GameState::DEAD) {
    DrawRectangle(0, 0, 1280, 720, Fade(BLACK, 0.7f));
    DrawText("VOUS AVEZ COULE",
             1280 / 2 - MeasureText("VOUS AVEZ COULE", 60) / 2, 250, 60, RED);
    if (GuiButton({1280 / 2.0f - 100, 400, 200, 50}, "RECOMMENCER"))
      state = GameState::CUSTOMIZE;
  }
}
