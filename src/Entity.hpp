#pragma once
#include <raylib.h>

class Entity {
public:
  int id;
  Vector3 position;
  float radius;
  bool active;

  static int nextId;

  Entity(Vector3 pos, float r) : position(pos), radius(r), active(true) {
    id = nextId++;
  }
  virtual ~Entity() = default;

  virtual void Update(float dt) = 0;
  virtual void Draw() = 0;
};
