#include "network_server.h"

#include "protocol.h"

#include <iostream>
#include <thread>

namespace mcp {

void runNetworkServer(MCPStatus& status, uint16_t port) {
    using asio::ip::udp;

    try {
        asio::io_context io_context;
        udp::socket socket(io_context, udp::endpoint(udp::v4(), port));

        // Heartbeat sender thread — sends at 1Hz when a remote endpoint is known.
        std::thread sender_thread([&]() {
            while (true) {
                std::this_thread::sleep_for(std::chrono::seconds(1));
                auto endpoint = status.remoteEndpoint();
                if (endpoint.address().to_string() != "0.0.0.0") {
                    int seq = status.heartbeatSentCount();
                    std::string msg = formatHeartbeat(seq);
                    socket.send_to(asio::buffer(msg), endpoint);
                    status.recordHeartbeatSent(getCurrentTime());
                }
            }
        });
        sender_thread.detach();

        // Receive loop — blocking, runs forever.
        while (true) {
            char data[1024];
            udp::endpoint remote_endpoint;
            size_t length = socket.receive_from(asio::buffer(data), remote_endpoint);

            std::string message(data, length);
            status.setRemoteEndpoint(remote_endpoint);

            if (isHeartbeat(message)) {
                status.recordHeartbeatReceived(getCurrentTime());
            } else if (auto cmd = parseControlCommand(message)) {
                status.recordCommandReceived(*cmd, message);
            }
        }
    } catch (std::exception& e) {
        std::cerr << "Network Error: " << e.what() << std::endl;
    }
}

}  // namespace mcp
