#include "dashboard.h"
#include "network_server.h"
#include "serial_forwarder.h"

#include <thread>

int main() {
    mcp::MCPStatus status("/dev/ttyUSB0");

    std::thread net_thread(mcp::runNetworkServer, std::ref(status), 8888);
    net_thread.detach();

    std::thread serial_thread(mcp::runSerialForwarder, std::ref(status));
    serial_thread.detach();

    mcp::runDashboard(status);

    return 0;
}
