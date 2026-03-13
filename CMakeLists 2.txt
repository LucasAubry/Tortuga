cmake_minimum_required(VERSION 3.14)
project(KartugaClone CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)
FetchContent_Declare(
    raylib
    GIT_REPOSITORY https://github.com/raysan5/raylib.git
    GIT_TAG        master
)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(raylib)

add_executable(kartuga 
    src/main.cpp 
    src/Game.cpp 
    src/Ship.cpp 
    src/Island.cpp 
    src/Loot.cpp
    src/Projectile.cpp
)

target_link_libraries(kartuga PRIVATE raylib)
target_include_directories(kartuga PRIVATE src)

if(APPLE)
    target_link_libraries(kartuga PRIVATE "-framework IOKit")
    target_link_libraries(kartuga PRIVATE "-framework Cocoa")
    target_link_libraries(kartuga PRIVATE "-framework OpenGL")
endif()
