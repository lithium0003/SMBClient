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
    
    private func wait(id: UUID) async {
        value -= 1
        if value >= 0 { return }
        await withCheckedContinuation {
            idlist.append(id)
            waiters[id] = $0
        }
    }
    
    @discardableResult
    public func wait(timeout: Duration) async -> waitResult {
        let id = UUID()
        return await withTaskGroup(of: waitResult.self) { group in
            group.addTask {
                await self.wait(id: id)
                return .success
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return .timeout
            }
            let v = await group.next()!
            group.cancelAll()
            if v == .timeout {
                value += 1
                if let i = idlist.firstIndex(of: id) {
                    idlist.remove(at: i)
                }
                waiters[id]?.resume()
                waiters.removeValue(forKey: id)
            }
            return v
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
