#include "Island.hpp"
#include <raymath.h>
#include <rlgl.h>
#include <stdlib.h>

Island::Island(Vector3 pos, float r, bool giant, bool merchant, bool shipwright,
               bool fisherman, bool capitalPlatform, bool solidCapitalIsland)
    : Entity(pos, r), isGiant(giant), isMerchant(merchant),
      isShipwright(shipwright), isFisherman(fisherman),
      isCapitalPlatform(capitalPlatform),
      isSolidCapitalIsland(solidCapitalIsland) {
  innerRadius = isGiant ? 150.0f : r * 0.6f;
  portOpeningWidth = isGiant ? 30.0f : 80.0f;

  if (isGiant) {
    portOpeningAngles.push_back(0.0f); // Just one small hole
  } else if (!isCapitalPlatform) {
    portOpeningAngles.push_back((float)(rand() % 360));
  }
}

void Island::Update(float dt) {
  // Islands don't move
}

void Island::Draw() {
  if (isCapitalPlatform) {
    rlPushMatrix();
    rlTranslatef(position.x, position.y + 5.0f, position.z);
    // Draw a wooden square platform (height 10, centered at 0, so top is +5.0f
    // locally)
    DrawCube(Vector3Zero(), radius * 2.0f, 10.0f, radius * 2.0f, DARKBROWN);
    DrawCubeWires(Vector3Zero(), radius * 2.0f, 10.0f, radius * 2.0f, BLACK);

    // Draw some decorative elements based on merchant type
    // Position them on top of the platform (Y = 5.0f + their height / 2)
    if (isMerchant) {
      DrawCube({0, 5.0f + 15.0f / 2.0f, 0}, 15.0f, 15.0f, 15.0f, GOLD);
    } else if (isShipwright) {
      DrawCube({0, 5.0f + 10.0f / 2.0f, 0}, 20.0f, 10.0f, 10.0f, PURPLE);
    } else if (isFisherman) {
      DrawCube({0, 5.0f + 15.0f / 2.0f, 0}, 10.0f, 15.0f, 10.0f, SKYBLUE);
    }
    rlPopMatrix();
    return;
  }

  float height = 40.0f;
  Color sandColor = {194, 178, 128, 255};
  Color grassColor = {34, 139, 34, 255};

  if (isSolidCapitalIsland) {
    rlPushMatrix();
    rlTranslatef(position.x, position.y, position.z);

    // Draw Sand Base (solid cylinder)
    DrawCylinder(Vector3Zero(), radius, radius, height * 0.5f, 32, sandColor);

    // Draw Grass Top (slightly smaller solid cylinder)
    rlTranslatef(0, height * 0.5f, 0);
    DrawCylinder(Vector3Zero(), radius - 5.0f, radius - 5.0f, height * 0.5f, 32,
                 grassColor);

    rlPopMatrix();
    return;
  }

  // We will draw the C-shape by drawing several overlapping cylinders in a
  // ring, skipping the opening
  int numSegments = isGiant ? 64 : 16;
  float angleStep = 360.0f / numSegments;
  float segmentRadius = (radius - innerRadius) * (isGiant ? 0.9f : 0.6f);
  float ringCenterRadius = innerRadius + (radius - innerRadius) / 2.0f;

  for (int i = 0; i < numSegments; i++) {
    float angle = i * angleStep;

    // Skip drawing if the angle is within ANY of the port openings
    bool insideOpening = false;
    for (float openingAngle : portOpeningAngles) {
      float df = angle - openingAngle;
      while (df > 180.0f)
        df -= 360.0f;
      while (df < -180.0f)
        df += 360.0f;

      if (fabs(df) < portOpeningWidth / 2.0f) {
        insideOpening = true;
        break;
      }
    }

    if (insideOpening)
      continue;

    Vector3 segmentPos = {
        position.x + cosf(angle * DEG2RAD) * ringCenterRadius, position.y,
        position.z + sinf(angle * DEG2RAD) * ringCenterRadius};

    // Draw Sand base
    rlPushMatrix();
    rlTranslatef(segmentPos.x, segmentPos.y, segmentPos.z);
    DrawCylinder(Vector3Zero(), segmentRadius, segmentRadius + 5.0f,
                 height * 0.5f, 12, sandColor);

    // Draw Grass top
    rlTranslatef(0, height * 0.5f, 0);
    DrawCylinder(Vector3Zero(), segmentRadius - 2.0f, segmentRadius - 2.0f,
                 height * 0.5f, 12, grassColor);

    // Decorative Cannons pointing outward along the ring
    if (i % 2 == 0) {
      rlPushMatrix();
      float t = angle * DEG2RAD;
      rlRotatef(-angle, 0, 1, 0);
      rlTranslatef(segmentRadius - 5.0f, 5.0f, 0);
      DrawCube(Vector3Zero(), 15.0f, 5.0f, 5.0f, DARKGRAY);
      rlPopMatrix();
    }

    // Decorative Houses on Shipwright Island
    if (isShipwright && i % 3 == 0) {
      rlPushMatrix();
      rlRotatef(-angle, 0, 1, 0);
      rlTranslatef(segmentRadius - 20.0f, 15.0f,
                   0); // Positioned inland from cannons
      DrawCube(Vector3Zero(), 20.0f, 20.0f, 20.0f, BEIGE);
      // Small Roof
      DrawCube({0, 12.0f, 0}, 22.0f, 5.0f, 22.0f, MAROON);
      rlPopMatrix();
    }

    rlPopMatrix();
  }
}
