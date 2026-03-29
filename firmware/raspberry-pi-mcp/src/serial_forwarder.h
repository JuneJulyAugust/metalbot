#pragma once

#include "mcp_status.h"

namespace raspberry_pi_mcp {

/// Runs the serial forwarder on the calling thread (blocking).
/// Sends steering/motor commands to Arduino via serial at 20Hz;
/// reads back acknowledgement strings.
void runSerialForwarder(MCPStatus& status);

}  // namespace raspberry_pi_mcp
