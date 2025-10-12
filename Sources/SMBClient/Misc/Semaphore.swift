import Foundation

public actor Semaphore {
    private var value: Int
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var idlist: [UUID] = []
    public enum waitResult {
        case timeout
        case success
    }
    
    public init(value: Int = 0) {
        self.value = value
    }
    
    public func wait() async {
        await wait(id: UUID())
    }
    
    func wait(id: UUID) async {
        value -= 1
        guard value < 0 else { return }
        await withCheckedContinuation {
            idlist.append(id)
            waiters[id] = $0
        }
    }
    
    public func wait(timeout: ContinuousClock.Instant.Duration) async -> waitResult {
        let id = UUID()
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    await self.wait(id: id)
                }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw CancellationError()
                }
                let _ = try await group.next()!
                group.cancelAll()
            }
            return .success
        }
        catch {
            value += 1
            if let i = idlist.firstIndex(of: id) {
                idlist.remove(at: i)
            }
            waiters[id]?.resume()
            waiters.removeValue(forKey: id)
            return .timeout
        }
    }
    
    public func signal() {
        value += 1
        guard let id = idlist.first else { return }
        idlist.removeFirst()
        waiters[id]?.resume()
        waiters.removeValue(forKey: id)
    }
}
