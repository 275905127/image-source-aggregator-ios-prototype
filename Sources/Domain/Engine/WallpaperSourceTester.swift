import Foundation

struct WallpaperSourceValidationIssue: Identifiable, Equatable, Sendable {
    enum Severity: String, Sendable {
        case error
        case warning
        case info
    }

    let id = UUID()
    let severity: Severity
    let title: String
    let message: String
}

struct WallpaperSourceTestReport: Equatable, Sendable {
    var sourceName: String
    var endpointDescription: String
    var issues: [WallpaperSourceValidationIssue]
    var sampleWallpapers: [Wallpaper]
    var hasMore: Bool?

    var isUsable: Bool {
        !issues.contains { $0.severity == .error }
    }

    var summary: String {
        if !isUsable {
            return "图源配置需要修正"
        }
        if sampleWallpapers.isEmpty {
            return "配置可用，但当前响应没有图片"
        }
        return "已解析 \(sampleWallpapers.count) 张图片"
    }
}

struct WallpaperSourceTester: Sendable {
    private let repository: WallpaperRepository

    init(repository: WallpaperRepository = WallpaperRepository()) {
        self.repository = repository
    }

    func validate(_ source: WallpaperSourceEngine) -> [WallpaperSourceValidationIssue] {
        var issues: [WallpaperSourceValidationIssue] = []
        let trimmedName = source.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            issues.append(.error("缺少名称", "图源需要一个便于识别的名称。"))
        }

        switch source.kind {
        case .wallhaven, .jsonAPI:
            if source.request.normalizedBaseURL.isEmpty {
                issues.append(.error("缺少 API 地址", "请填写 baseURL 或从完整 URL 导入。"))
            }
            if source.request.pathTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.warning("缺少路径", "根路径接口可以留空；否则建议填写类似 /search 或 /images。"))
            }
            if source.kind == .jsonAPI {
                if source.mapping.fullImageURLPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.error("缺少图片映射", "JSON API 图源至少需要 fullImageURLPath 或 image 映射。"))
                }
                if source.mapping.itemsPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.info("根对象映射", "itemsPath 为空时会尝试把根数组或根对象当作图片数据。"))
                }
            }
            if source.request.method.uppercased() != "GET" {
                issues.append(.warning("暂只验证 GET", "当前仓储层会构造该 method，但测试器只适合无请求体的接口。"))
            }
            if source.hasAPIKey {
                switch source.request.apiKeyPlacement {
                case .query where source.request.apiKeyQueryName.isEmpty:
                    issues.append(.warning("密钥参数名为空", "query 模式下建议填写 apikey、key 或 token。"))
                case .header, .bearer where source.request.apiKeyQueryName.isEmpty:
                    issues.append(.info("使用默认 Authorization", "header/bearer 模式会使用 Authorization。"))
                default:
                    break
                }
            }
        case .directLinks:
            let validURLs = source.validDirectImageURLs
            if validURLs.isEmpty {
                issues.append(.error("缺少图片直链", "请至少填写一个可访问的 http/https 图片地址。"))
            }
            let invalidCount = source.directImages.count - validURLs.count
            if invalidCount > 0 {
                issues.append(.warning("有无效直链", "已忽略 \(invalidCount) 条空白或无效 URL。"))
            }
        }
        return issues
    }

    func test(_ source: WallpaperSourceEngine, query: String = "") async -> WallpaperSourceTestReport {
        let issues = validate(source)
        let endpointDescription = endpointDescription(for: source, query: query)
        guard !issues.contains(where: { $0.severity == .error }) else {
            return WallpaperSourceTestReport(
                sourceName: source.name,
                endpointDescription: endpointDescription,
                issues: issues,
                sampleWallpapers: [],
                hasMore: nil
            )
        }

        do {
            let result = try await repository.fetchWallpapers(
                query: query,
                page: 1,
                sorting: .toplist,
                configuration: WallhavenSourceConfiguration(),
                sourceEngine: source
            )
            var reportIssues = issues
            if result.wallpapers.isEmpty {
                reportIssues.append(.warning("没有解析到图片", "请求成功，但映射规则没有产出图片。请检查 itemsPath 和图片 URL path。"))
            }
            return WallpaperSourceTestReport(
                sourceName: source.name,
                endpointDescription: endpointDescription,
                issues: reportIssues,
                sampleWallpapers: Array(result.wallpapers.prefix(6)),
                hasMore: result.hasMore
            )
        } catch let error as NetworkError {
            return failureReport(
                source: source,
                endpointDescription: endpointDescription,
                issues: issues,
                message: error.localizedDescription
            )
        } catch {
            return failureReport(
                source: source,
                endpointDescription: endpointDescription,
                issues: issues,
                message: error.localizedDescription
            )
        }
    }

    private func failureReport(
        source: WallpaperSourceEngine,
        endpointDescription: String,
        issues: [WallpaperSourceValidationIssue],
        message: String
    ) -> WallpaperSourceTestReport {
        var reportIssues = issues
        reportIssues.append(.error("测试请求失败", message))
        return WallpaperSourceTestReport(
            sourceName: source.name,
            endpointDescription: endpointDescription,
            issues: reportIssues,
            sampleWallpapers: [],
            hasMore: nil
        )
    }

    private func endpointDescription(for source: WallpaperSourceEngine, query: String) -> String {
        switch source.kind {
        case .directLinks:
            return "\(source.validDirectImageURLs.count) 张图片直链"
        case .wallhaven, .jsonAPI:
            guard let endpoint = try? source.endpoint(query: query, page: 1),
                  let request = try? endpoint.buildURLRequest() else {
                return source.request.normalizedBaseURL + source.request.pathTemplate
            }
            return request.url?.absoluteString ?? source.request.normalizedBaseURL + source.request.pathTemplate
        }
    }
}

private extension WallpaperSourceValidationIssue {
    static func error(_ title: String, _ message: String) -> WallpaperSourceValidationIssue {
        WallpaperSourceValidationIssue(severity: .error, title: title, message: message)
    }

    static func warning(_ title: String, _ message: String) -> WallpaperSourceValidationIssue {
        WallpaperSourceValidationIssue(severity: .warning, title: title, message: message)
    }

    static func info(_ title: String, _ message: String) -> WallpaperSourceValidationIssue {
        WallpaperSourceValidationIssue(severity: .info, title: title, message: message)
    }
}

extension WallpaperSourceEngine {
    var validDirectImageURLs: [URL] {
        directImages.compactMap { rawValue in
            Self.validDirectImageURL(from: rawValue)
        }
    }

    static func validDirectImageURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }
}
