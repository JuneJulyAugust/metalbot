#include "serial_forwarder.h"

#include "protocol.h"

#include <fcntl.h>
#include <termios.h>
#include <unistd.h>

#include <iostream>
#include <memory>
#include <thread>

namespace mcp {

void runSerialForwarder(MCPStatus& status) {
    asio::io_context io;
    std::unique_ptr<asio::serial_port> serial;

    char read_buf[1024];
    std::string read_line;
    std::string port_name = status.serialPortName();

    while (true) {
        try {
            if (!serial || !serial->is_open()) {
                // Check if device physically exists before trying to open
                if (access(port_name.c_str(), F_OK) == -1) {
                    status.setSerialState(false, "Waiting for USB device...");
                    std::this_thread::sleep_for(std::chrono::seconds(1));
                    continue;
                }

                serial = std::make_unique<asio::serial_port>(io, port_name);
                serial->set_option(asio::serial_port_base::baud_rate(115200));

                int fd = serial->native_handle();
                int flags = fcntl(fd, F_GETFL, 0);
                fcntl(fd, F_SETFL, flags | O_NONBLOCK);

                status.setSerialState(true, "Booting Arduino (3.5s)...");

                // Wait for Arduino auto-reset and ESC arming
                std::this_thread::sleep_for(std::chrono::milliseconds(3500));

                // Flush stale junk data that arrived during boot
                tcflush(fd, TCIOFLUSH);

                status.setSerialState(true, "Arduino ready");
            }

            ControlCommand ctrl = status.currentControl();
            std::string cmd = formatSerialCommand(ctrl);

            // Write with error code to catch disconnects immediately
            std::error_code ec;
            asio::write(*serial, asio::buffer(cmd), ec);
            if (ec) {
                throw std::runtime_error("Write failed: " + ec.message());
            }

            // Read feedback
            size_t len = serial->read_some(asio::buffer(read_buf, sizeof(read_buf)), ec);
            if (!ec && len > 0) {
                for (size_t i = 0; i < len; ++i) {
                    if (read_buf[i] == '\n') {
                        // Truncate if too long to prevent UI layout issues
                        if (read_line.length() > 40) {
                            read_line = read_line.substr(0, 40) + "...";
                        }
                        status.setSerialState(true, read_line);
                        read_line.clear();
                    } else if (read_buf[i] != '\r') {
                        read_line += read_buf[i];
                    }
                }
            } else if (ec && ec != asio::error::would_block && ec != asio::error::try_again) {
                throw std::runtime_error("Read failed: " + ec.message());
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(50));  // 20Hz update rate

        } catch (std::exception& e) {
            status.setSerialState(false, std::string("Err: ") + e.what());
            if (serial) {
                std::error_code ec;
                serial->close(ec);
                serial.reset();
            }
            std::this_thread::sleep_for(std::chrono::seconds(2));
        }
    }
}

}  // namespace mcp
