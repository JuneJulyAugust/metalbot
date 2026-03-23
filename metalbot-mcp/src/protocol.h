#pragma once

#include <optional>
#include <string>
#include <string_view>

namespace mcp {

/// Pure value type representing a steering + motor command.
struct ControlCommand {
    float steering = 0.0f;
    float motor = 0.0f;
};

// ---------------------------------------------------------------------------
// Message parsing — pure functions, zero I/O dependencies.
// ---------------------------------------------------------------------------

/// Parse a UDP command message (e.g. "cmd:s=0.50,m=-1.00") into a ControlCommand.
/// Returns std::nullopt for any malformed or unrecognized input.
std::optional<ControlCommand> parseControlCommand(std::string_view msg);

/// Returns true if the message is an iPhone heartbeat (starts with "hb_iphone:").
bool isHeartbeat(std::string_view msg);

// ---------------------------------------------------------------------------
// Message formatting — pure functions, zero I/O dependencies.
// ---------------------------------------------------------------------------

/// Format a ControlCommand for serial transmission to the Arduino.
/// Example output: "S:0.50,M:0.75\n"
std::string formatSerialCommand(const ControlCommand& cmd);

/// Format a Pi heartbeat message with the given sequence number.
/// Example output: "hb_pi:42"
std::string formatHeartbeat(int seq);

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

/// Returns current wall-clock time as "HH:MM:SS".
std::string getCurrentTime();

}  // namespace mcp
