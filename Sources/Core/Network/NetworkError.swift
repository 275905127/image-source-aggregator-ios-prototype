import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingFailed(Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .invalidResponse: return "无效的服务器响应"
        case .httpError(let code, let data):
            return Self.httpErrorDescription(statusCode: code, data: data)
        case .decodingFailed(let error): return "数据解析失败: \(error.localizedDescription)"
        case .cancelled: return "请求已取消"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .httpError(let code, _): return code >= 500 || code == 429
        case .invalidResponse: return true
        default: return false
        }
    }

    private static func httpErrorDescription(statusCode: Int, data: Data?) -> String {
        let serverMessage = data.flatMap(serverMessage)
        let prefix: String
        switch statusCode {
        case 400:
            prefix = "请求参数无效"
        case 401, 403:
            prefix = "密钥无效或无权限访问"
        case 404:
            prefix = "接口地址不存在"
        case 422:
            prefix = "图源参数不被服务器接受"
        case 429:
            prefix = "请求过快，请稍后再试"
        case 500...599:
            prefix = "图源服务器暂时不可用"
        default:
            prefix = "服务器错误 (HTTP \(statusCode))"
        }
        guard let serverMessage, !serverMessage.isEmpty else {
            return "\(prefix) (HTTP \(statusCode))"
        }
        return "\(prefix)：\(serverMessage)"
    }

    private static func serverMessage(from data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) {
            if let message = value(in: object, atAny: ["error", "message", "detail", "errors.0", "errors.0.message"]) {
                return message
            }
        }
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return String(text.prefix(160))
    }

    private static func value(in root: Any, atAny paths: [String]) -> String? {
        for path in paths {
            if let value = value(in: root, at: path) {
                if let string = value as? String { return string }
                if let number = value as? NSNumber { return number.stringValue }
            }
        }
        return nil
    }

    private static func value(in root: Any, at path: String) -> Any? {
        var current: Any? = root
        for component in path.split(separator: ".") {
            guard let unwrapped = current else { return nil }
            if let dictionary = unwrapped as? [String: Any] {
                current = dictionary[String(component)]
            } else if let array = unwrapped as? [Any],
                      let index = Int(component),
                      array.indices.contains(index) {
                current = array[index]
            } else {
                return nil
            }
        }
        return current
    }
}
