#include "protocol.h"

#include <chrono>
#include <cmath>
#include <iomanip>
#include <sstream>

namespace mcp {

std::optional<ControlCommand> parseControlCommand(std::string_view msg) {
    // Expected format: "cmd:s=<float>,m=<float>"
    constexpr std::string_view kPrefix = "cmd:";
    if (msg.substr(0, kPrefix.size()) != kPrefix) {
        return std::nullopt;
    }

    const auto body = msg.substr(kPrefix.size());

    auto findValue = [&](std::string_view key) -> std::optional<float> {
        auto pos = body.find(key);
        if (pos == std::string_view::npos) return std::nullopt;
        auto start = pos + key.size();
        // Find end: next comma or end of string
        auto end = body.find(',', start);
        auto token = body.substr(start, end == std::string_view::npos ? end : end - start);
        try {
            return std::stof(std::string(token));
        } catch (...) {
            return std::nullopt;
        }
    };

    auto s = findValue("s=");
    auto m = findValue("m=");
    if (!s.has_value() || !m.has_value()) return std::nullopt;

    // Clamp to valid range [-1, 1]
    auto clamp = [](float v) { return std::fmax(-1.0f, std::fmin(1.0f, v)); };
    return ControlCommand{clamp(*s), clamp(*m)};
}

bool isHeartbeat(std::string_view msg) {
    constexpr std::string_view kPrefix = "hb_iphone:";
    return msg.substr(0, kPrefix.size()) == kPrefix;
}

std::string formatSerialCommand(const ControlCommand& cmd) {
    std::ostringstream ss;
    ss << std::fixed << std::setprecision(2)
       << "S:" << cmd.steering << ",M:" << cmd.motor << "\n";
    return ss.str();
}

std::string formatHeartbeat(int seq) {
    return "hb_pi:" + std::to_string(seq);
}

std::string getCurrentTime() {
    auto now = std::chrono::system_clock::now();
    auto now_t = std::chrono::system_clock::to_time_t(now);
    std::ostringstream ss;
    ss << std::put_time(std::localtime(&now_t), "%H:%M:%S");
    return ss.str();
}

}  // namespace mcp
