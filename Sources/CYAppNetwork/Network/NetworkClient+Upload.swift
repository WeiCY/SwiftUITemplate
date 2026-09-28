import Foundation
import Alamofire
import CYAppCore

// MARK: - 上传 / 下载

extension CYNetworkClient {

    // MARK: - 上传

    /// 多文件上传（multipart/form-data，带进度回调）
    ///
    /// 支持同时上传多个文件和附加参数：
    /// ```swift
    /// let avatar: Avatar = try await networkClient.upload(
    ///     UserEndpoint.uploadAvatar,
    ///     parts: [CYMultipartPart(data: imageData, mimeType: "image/jpeg")]
    /// )
    /// ```
    public func upload<T: Decodable & Sendable>(
        _ endpoint: CYEndpoint,
        parts: [CYMultipartPart],
        additionalParams: [String: String]?,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> T {
        let limitMB = CYAppConstants.maxUploadSizeMB
        let limitBytes = limitMB * 1_024 * 1_024
        let totalBytes = parts.reduce(0) { $0 + $1.data.count }
        guard totalBytes <= limitBytes else {
            CYLogger.network.error(
                "Upload rejected: \(totalBytes) bytes exceeds \(limitMB) MB limit for \(endpoint.path)"
            )
            throw CYNetworkError.payloadTooLarge(limitMB: limitMB)
        }
        return try await performRequest(endpoint) {
            var urlRequest = try self.buildURLRequest(for: endpoint)
            try await self.applyRequestInterceptors(to: &urlRequest, authentication: endpoint.authentication)

            let uploadTask = self.session.upload(multipartFormData: { formData in
                for part in parts {
                    formData.append(part.data, withName: part.paramName, fileName: part.fileName, mimeType: part.mimeType)
                }
                if let body = endpoint.body {
                    for (key, value) in body {
                        guard let string = value.multipartStringValue else { continue }
                        formData.append(Data(string.utf8), withName: key)
                    }
                }
                if let additionalParams {
                    for (key, value) in additionalParams {
                        if let d = value.data(using: .utf8) {
                            formData.append(d, withName: key)
                        }
                    }
                }
            }, with: urlRequest)
            .validate(statusCode: 200..<300)
            .uploadProgress { uploadProgress in
                progress?(uploadProgress.fractionCompleted)
            }
            .serializingDecodable(CYAPIResponse<T>.self, decoder: self.makeDecoder(for: endpoint))

            let response = await uploadTask.response
            let apiResponse: CYAPIResponse<T>
            do {
                apiResponse = try await uploadTask.value
            } catch {
                // 解码失败：携带终态响应抛出，由上层在终态统一应用响应拦截器
                throw NetworkFailure(
                    cyError: self.mapNetworkError(error, data: response.data),
                    response: response.response,
                    data: response.data
                )
            }

            try await self.applyResponseInterceptors(response.response, data: response.data)
            return try self.resolveData(apiResponse)
        }
    }

    // MARK: - 下载

    /// 下载文件到指定路径（带进度回调；取消会传播到底层请求，错误映射为 `.cancelled`）
    ///
    /// ```swift
    /// let fileURL = try await networkClient.download(
    ///     FileEndpoint.download(id: "123"),
    ///     to: documentsDirectory.appendingPathComponent("file.pdf")
    /// )
    /// ```
    public func download(
        _ endpoint: CYEndpoint,
        to fileURL: URL,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        try await performRequest(endpoint) {
            var urlRequest = try self.buildURLRequest(for: endpoint)
            try await self.applyRequestInterceptors(to: &urlRequest, authentication: endpoint.authentication)
            let destination: DownloadRequest.Destination = { _, _ in
                (fileURL, [.removePreviousFile, .createIntermediateDirectories])
            }

            // 先创建 Alamofire 请求（取消处理器需要持有它）
            let downloadRequest = self.session.download(urlRequest, to: destination)
                .validate(statusCode: 200..<300)
                .downloadProgress { downloadProgress in
                    progress?(downloadProgress.fractionCompleted)
                }

            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    downloadRequest.response { response in
                        Task {
                            if let error = response.error {
                                // 下载失败（含取消）：携带终态响应抛出，由上层在终态统一应用响应拦截器
                                continuation.resume(throwing: NetworkFailure(
                                    cyError: self.mapNetworkError(error, data: response.resumeData),
                                    response: response.response,
                                    data: response.resumeData
                                ))
                            } else if let fileURL = response.fileURL {
                                try? await self.applyResponseInterceptors(response.response, data: response.resumeData)
                                continuation.resume(returning: fileURL)
                            } else {
                                continuation.resume(throwing: CYNetworkError.unknown)
                            }
                        }
                    }
                }
            } onCancel: {
                downloadRequest.cancel()
            }
        }
    }
}

// MARK: - multipart 表单字段转换

private extension CYJSONValue {
    /// multipart 表单字段的字符串表示：字符串去引号，数值/布尔/空转为文本，
    /// 数组/对象不支持作为表单字段（返回 nil，调用方跳过）。
    var multipartStringValue: String? {
        switch self {
        case .string(let v): return v
        case .int(let v): return "\(v)"
        case .double(let v): return "\(v)"
        case .bool(let v): return "\(v)"
        case .null: return "null"
        case .array, .object: return nil
        }
    }
}
