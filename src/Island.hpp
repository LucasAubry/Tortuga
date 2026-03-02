#pragma once
#include "Entity.hpp"
#include <vector>

class Island : public Entity {
public:
  float innerRadius;
  std::vector<float> portOpeningAngles;
  float portOpeningWidth;

  bool isGiant;
  bool isMerchant;
  bool isShipwright;
  bool isFisherman;

  Island(Vector3 pos, float r, bool giant = false, bool merchant = false,
         bool shipwright = false, bool fisherman = false);

  void Update(float dt) override;
  void Draw() override;
};
