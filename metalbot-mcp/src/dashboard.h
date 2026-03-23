#pragma once

#include "mcp_status.h"

namespace mcp {

/// Runs the FTXUI fullscreen dashboard on the calling thread (blocking).
/// Reads status via MCPStatus::snapshot(). Exits on 'q' keypress.
void runDashboard(MCPStatus& status);

}  // namespace mcp
