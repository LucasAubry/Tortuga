#pragma once
#include "Island.hpp"
#include "Loot.hpp"
#include "Projectile.hpp"
#include "Ship.hpp"
#include <raymath.h>
#include <string>
#include <vector>

enum class GameState {
  MENU,
  CUSTOMIZE,
  PLAYING,
  DEAD,
  TOWN_MENU,
  SETTINGS,
  FULL_MAP,
  UPGRADE_MENU,
  SHIPWRIGHT_MENU
};

enum class QuestType { MERCHANT, MILITARY, DIPLOMATIC, FISHING };

struct Quest {
  std::string description;
  QuestType type;
  int rewardGold;
  int originIslandId; // for merchant (where it was bought)
  int targetIslandId; // for merchant/diplomatic
  int targetShipId;   // for military (-1 if not applicable)
  int stage;          // 0: Initial, 1: Returning (merchant)
  bool isCompleted;
  Vector3 targetLocation; // For Diplomatic
  float timer;            // For Diplomatic/Fishing
  int targetAmount;       // For Fishing
  int currentAmount;      // For Fishing
};

enum class FishingState { INACTIVE, WAITING_FOR_BITE, QTE, RESULT };

struct FishingZone {
  Vector3 position;
  float radius;
  int fishRemaining;
};

class Game {
private:
  Game() {}
  static Game *instance;

public:
  std::vector<Ship> ships;
  std::vector<Island> islands;
  std::vector<Projectile> projectiles;
  std::vector<Loot> lootDrops;
  std::vector<Quest> activeQuests;

  Camera3D camera;

  GameState state;
  bool showFullMap;

  // Camera Orbit
  Vector2 cameraAngle;
  float cameraDistance;

  // Customization Settings
  ShipClass selectedClass;
  Color selectedColor;

  // Environment (Wind Zones)
  struct WindZone {
    Vector3 pos;
    float radius;
    Vector2 direction;
    float strength;

    Vector2 targetDirection;
    float targetStrength;
    float timer;
  };
  std::vector<WindZone> windZones;

  Vector2 windDirection; // Kept for legacy/global visuals
  float windStrength;

  Vector2 targetWindDirection;
  float targetWindStrength;
  float windChangeTimer;

  struct WindParticle {
    Vector3 pos;
    float life;
  };
  std::vector<WindParticle> windParticles;

  // Config / Options
  float masterVolume;
  bool soundEnabled;

  int keyUp, keyDown, keyLeft, keyRight, keyFire, keyMap, keyInteract;
  int remappingKey; // 0: none, 1: up, 2: down, 3: left, 4: right, 5: fire, 6:
                    // map

  Island *parkedIsland;
  Island *lastMenuIsland;
  bool menuLocked;
  float menuCooldownTimer;

  // Fishing Minigame State
  std::vector<FishingZone> fishingZones;
  FishingState fishingState;
  FishingZone *activeFishingZone;
  float fishingTimer;
  float fishingQtePos;
  float fishingQteTargetStart;
  float fishingQteWidth;
  int fishingQteDir;
  std::string fishingResultMsg;

  static Game *GetInstance();

  void Init();
  void SpawnPlayer();
  void SpawnLoot(Vector3 pos);
  void Update(float dt);
  void Draw();
  void SpawnProjectile(Vector3 pos, Vector3 velocity, float damage,
                       bool isPlayer, Ship *owner);
};
