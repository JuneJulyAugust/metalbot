cmake_minimum_required(VERSION 3.16)
project(metalbot-mcp)

set(CMAKE_CXX_STANDARD 17)

# --- Tests (enabled with -DBUILD_TESTING=ON) ---
# Tests only depend on protocol.cpp (pure C++17) and GoogleTest.
# They can be built on any platform without FTXUI or asio.

option(BUILD_TESTING "Build unit tests" OFF)
if(BUILD_TESTING)
    include(FetchContent)
    FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.14.0
    )
    FetchContent_MakeAvailable(googletest)

    enable_testing()

    add_executable(metalbot-mcp-tests
        src/protocol.cpp
        tests/protocol_test.cpp
    )
    target_include_directories(metalbot-mcp-tests PRIVATE src)
    target_link_libraries(metalbot-mcp-tests
        PRIVATE GTest::gtest_main
    )

    include(GoogleTest)
    gtest_discover_tests(metalbot-mcp-tests)
endif()

# --- Main executable (requires FTXUI + asio, typically built on Pi) ---
# Only build main executable when not in test-only mode.

option(BUILD_MCP_EXECUTABLE "Build the main metalbot-mcp executable" ON)
if(BUILD_MCP_EXECUTABLE)
    add_subdirectory(FTXUI)
    find_package(Threads REQUIRED)

    set(MCP_SOURCES
        src/protocol.cpp
        src/network_server.cpp
        src/serial_forwarder.cpp
        src/dashboard.cpp
        src/main.cpp
    )

    add_executable(metalbot-mcp ${MCP_SOURCES})

    target_include_directories(metalbot-mcp PRIVATE src)
    target_link_libraries(metalbot-mcp
        PRIVATE ftxui::screen
        PRIVATE ftxui::dom
        PRIVATE ftxui::component
        PRIVATE Threads::Threads
    )
endif()
