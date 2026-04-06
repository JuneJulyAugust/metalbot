import Foundation

/// Routes messages from TelegramGateway to AgentRuntime and sends replies back.
final class GatewayBridge: TelegramGatewayDelegate {

    let runtime: AgentRuntime
    let gateway: TelegramGateway

    init(runtime: AgentRuntime, gateway: TelegramGateway) {
        self.runtime = runtime
        self.gateway = gateway
    }

    func gateway(_ gw: TelegramGateway, didReceive message: TelegramMessage) {
        let response = runtime.handleMessage(message.text)
        Task {
            try? await gw.sendReply(chatId: message.chatId, text: response)
        }
    }
}
