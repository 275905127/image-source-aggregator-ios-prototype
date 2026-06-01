import Foundation

actor RequestScheduler {
    private let maxConcurrent: Int
    private var activeCount = 0
    private var pending: [(priority: Int, task: () async throws -> Void)] = []

    init(maxConcurrent: Int = 5) {
        self.maxConcurrent = maxConcurrent
    }

    func schedule<T>(priority: Int = 0, operation: @escaping () async throws -> T) async throws -> T {
        if activeCount < maxConcurrent {
            activeCount += 1
            defer { activeCount -= 1; Task { await processNext() } }
            return try await operation()
        }
        return try await withCheckedThrowingContinuation { continuation in
            pending.append((priority, {
                do {
                    let result = try await operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }))
            pending.sort { $0.priority > $1.priority }
        }
    }

    private func processNext() {
        guard activeCount < maxConcurrent, !pending.isEmpty else { return }
        let (_, task) = pending.removeFirst()
        activeCount += 1
        Task {
            defer { activeCount -= 1; Task { await processNext() } }
            try? await task()
        }
    }
}
