#include <raylib.h>
#define RAYGUI_IMPLEMENTATION
#include "Game.hpp"
#include "raygui.h"

int main() {
  InitWindow(1280, 720, "Kartuga Clone C++");
  SetTargetFPS(60);

  Game::GetInstance()->Init();

  while (!WindowShouldClose()) {
    float dt = GetFrameTime();

    Game::GetInstance()->Update(dt);

    BeginDrawing();
    ClearBackground({0, 80, 180, 255}); // Ocean color

    Game::GetInstance()->Draw();

    EndDrawing();
  }

  CloseWindow();
  return 0;
}
