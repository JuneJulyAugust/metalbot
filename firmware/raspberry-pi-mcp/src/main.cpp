#include "dashboard.h"
#include "network_server.h"
#include "serial_forwarder.h"

#include <thread>

int main() {
    raspberry_pi_mcp::MCPStatus status("/dev/ttyUSB0");

    std::thread net_thread(raspberry_pi_mcp::runNetworkServer, std::ref(status), 8888);
    net_thread.detach();

    std::thread serial_thread(raspberry_pi_mcp::runSerialForwarder, std::ref(status));
    serial_thread.detach();

    raspberry_pi_mcp::runDashboard(status);

    return 0;
}
