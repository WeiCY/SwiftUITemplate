import Foundation

// MARK: - URLRequest 扩展
//
// 将 URLRequest 转为 cURL 命令，方便调试和复现请求。
//
// 用法：
// ```swift
// var request = URLRequest(url: url)
// request.httpMethod = "POST"
// print(request.cURL)  // 输出完整的 cURL 命令
// ```

extension URLRequest {
    
    /// 生成 cURL 命令字符串（调试用）
    public var cURL: String {
        guard let url = url else { return "" }
        var baseCommand = #"curl "\#(url.absoluteString)""#
        
        if httpMethod == "HEAD" {
            baseCommand += " --head"
        }
        
        var command = [baseCommand]
        
        if let method = httpMethod, method != "GET" && method != "HEAD" {
            command.append("-X \(method)")
        }
        
        if let headers = allHTTPHeaderFields {
            for (key, value) in headers where key != "Cookie" {
                command.append("-H '\(key): \(value)'")
            }
        }
        
        if let data = httpBody, let body = String(data: data, encoding: .utf8) {
            command.append("-d '\(body)'")
        }
        
        return command.joined(separator: " \\\n\t")
    }
}
