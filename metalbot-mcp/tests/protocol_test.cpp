#include "protocol.h"

#include <gtest/gtest.h>

#include <cmath>
#include <string>

using namespace mcp;

// ---------------------------------------------------------------------------
// parseControlCommand
// ---------------------------------------------------------------------------

TEST(Protocol, ParseValidCommand) {
    auto result = parseControlCommand("cmd:s=0.50,m=-1.00");
    ASSERT_TRUE(result.has_value());
    EXPECT_NEAR(result->steering, 0.50f, 1e-4f);
    EXPECT_NEAR(result->motor, -1.00f, 1e-4f);
}

TEST(Protocol, ParseZeroValues) {
    auto result = parseControlCommand("cmd:s=0.00,m=0.00");
    ASSERT_TRUE(result.has_value());
    EXPECT_NEAR(result->steering, 0.0f, 1e-4f);
    EXPECT_NEAR(result->motor, 0.0f, 1e-4f);
}

TEST(Protocol, ParseNegativeValues) {
    auto result = parseControlCommand("cmd:s=-0.75,m=-0.25");
    ASSERT_TRUE(result.has_value());
    EXPECT_NEAR(result->steering, -0.75f, 1e-4f);
    EXPECT_NEAR(result->motor, -0.25f, 1e-4f);
}

TEST(Protocol, ParseClampsOverflowValues) {
    auto result = parseControlCommand("cmd:s=5.00,m=-10.00");
    ASSERT_TRUE(result.has_value());
    EXPECT_NEAR(result->steering, 1.0f, 1e-4f);
    EXPECT_NEAR(result->motor, -1.0f, 1e-4f);
}

TEST(Protocol, ParseRejectsGarbage) {
    EXPECT_FALSE(parseControlCommand("garbage").has_value());
}

TEST(Protocol, ParseRejectsEmptyString) {
    EXPECT_FALSE(parseControlCommand("").has_value());
}

TEST(Protocol, ParseRejectsMissingMotor) {
    EXPECT_FALSE(parseControlCommand("cmd:s=0.50").has_value());
}

TEST(Protocol, ParseRejectsMissingSteering) {
    EXPECT_FALSE(parseControlCommand("cmd:m=0.50").has_value());
}

TEST(Protocol, ParseRejectsHeartbeatAsCommand) {
    EXPECT_FALSE(parseControlCommand("hb_iphone:5").has_value());
}

TEST(Protocol, ParseRejectsWrongPrefix) {
    EXPECT_FALSE(parseControlCommand("CMD:s=0.50,m=0.50").has_value());
}

// ---------------------------------------------------------------------------
// isHeartbeat
// ---------------------------------------------------------------------------

TEST(Protocol, IsHeartbeatValid) {
    EXPECT_TRUE(isHeartbeat("hb_iphone:5"));
    EXPECT_TRUE(isHeartbeat("hb_iphone:0"));
    EXPECT_TRUE(isHeartbeat("hb_iphone:123456"));
}

TEST(Protocol, IsHeartbeatRejectsOther) {
    EXPECT_FALSE(isHeartbeat("cmd:s=0.00,m=0.00"));
    EXPECT_FALSE(isHeartbeat("hb_pi:5"));
    EXPECT_FALSE(isHeartbeat(""));
    EXPECT_FALSE(isHeartbeat("hello"));
}

// ---------------------------------------------------------------------------
// formatSerialCommand
// ---------------------------------------------------------------------------

TEST(Protocol, FormatSerialCommandPositive) {
    std::string result = formatSerialCommand({0.50f, 0.75f});
    EXPECT_EQ(result, "S:0.50,M:0.75\n");
}

TEST(Protocol, FormatSerialCommandNegative) {
    std::string result = formatSerialCommand({-1.00f, -0.25f});
    EXPECT_EQ(result, "S:-1.00,M:-0.25\n");
}

TEST(Protocol, FormatSerialCommandZero) {
    std::string result = formatSerialCommand({0.0f, 0.0f});
    EXPECT_EQ(result, "S:0.00,M:0.00\n");
}

// ---------------------------------------------------------------------------
// formatHeartbeat
// ---------------------------------------------------------------------------

TEST(Protocol, FormatHeartbeat) {
    EXPECT_EQ(formatHeartbeat(0), "hb_pi:0");
    EXPECT_EQ(formatHeartbeat(42), "hb_pi:42");
    EXPECT_EQ(formatHeartbeat(99999), "hb_pi:99999");
}

// ---------------------------------------------------------------------------
// Round-trip: format → parse consistency
// ---------------------------------------------------------------------------

TEST(Protocol, RoundTripCommandFormat) {
    // Verify that what we send from iOS can be parsed correctly on MCP side.
    // iOS sends: "cmd:s=0.50,m=-0.75"
    // MCP should parse it into ControlCommand{0.50, -0.75}
    // MCP then formats for serial: "S:0.50,M:-0.75\n"
    auto parsed = parseControlCommand("cmd:s=0.50,m=-0.75");
    ASSERT_TRUE(parsed.has_value());
    std::string serial = formatSerialCommand(*parsed);
    EXPECT_EQ(serial, "S:0.50,M:-0.75\n");
}

// ---------------------------------------------------------------------------
// getCurrentTime — just verify it returns a non-empty, reasonable string.
// ---------------------------------------------------------------------------

TEST(Protocol, GetCurrentTimeFormat) {
    std::string t = getCurrentTime();
    EXPECT_FALSE(t.empty());
    // Expect HH:MM:SS format → exactly 8 characters
    EXPECT_EQ(t.size(), 8u);
    EXPECT_EQ(t[2], ':');
    EXPECT_EQ(t[5], ':');
}
