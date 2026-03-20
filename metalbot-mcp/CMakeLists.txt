cmake_minimum_required(VERSION 3.16)
project(metalbot-mcp)

set(CMAKE_CXX_STANDARD 17)

# FTXUI
add_subdirectory(FTXUI)

# ASIO (header only)
find_package(Threads REQUIRED)

add_executable(metalbot-mcp src/main.cpp)

target_include_directories(metalbot-mcp PRIVATE src)
target_link_libraries(metalbot-mcp 
    PRIVATE ftxui::screen
    PRIVATE ftxui::dom
    PRIVATE ftxui::component
    PRIVATE Threads::Threads
)
