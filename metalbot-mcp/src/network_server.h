#pragma once

#include "mcp_status.h"

#include <cstdint>

namespace mcp {

/// Runs the UDP network server on the calling thread (blocking).
/// Receives heartbeats and commands from iPhone; sends heartbeats back.
void runNetworkServer(MCPStatus& status, uint16_t port);

}  // namespace mcp
