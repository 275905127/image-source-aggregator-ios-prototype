import Foundation

struct HTTPClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let maxRetries: Int

    init(session: URLSession = .shared, maxRetries: Int = 2) {
        self.session = session
        self.maxRetries = maxRetries
        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let request = try endpoint.buildURLRequest()
        return try await executeWithRetry(request: request, retriesLeft: maxRetries)
    }

    func requestData(_ endpoint: Endpoint) async throws -> Data {
        let request = try endpoint.buildURLRequest()
        return try await executeDataWithRetry(request: request, retriesLeft: maxRetries)
    }

    private func executeWithRetry<T: Decodable>(request: URLRequest, retriesLeft: Int) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingFailed(error)
            }
        } catch let error as NetworkError {
            if error.isRetryable && retriesLeft > 0 {
                try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * (maxRetries - retriesLeft + 1)))
                return try await executeWithRetry(request: request, retriesLeft: retriesLeft - 1)
            }
            throw error
        } catch {
            if (error as? URLError)?.code == .cancelled { throw NetworkError.cancelled }
            throw NetworkError.invalidResponse
        }
    }

    private func executeDataWithRetry(request: URLRequest, retriesLeft: Int) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            return data
        } catch let error as NetworkError {
            if error.isRetryable && retriesLeft > 0 {
                try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * (maxRetries - retriesLeft + 1)))
                return try await executeDataWithRetry(request: request, retriesLeft: retriesLeft - 1)
            }
            throw error
        } catch {
            if (error as? URLError)?.code == .cancelled { throw NetworkError.cancelled }
            throw NetworkError.invalidResponse
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }
}
