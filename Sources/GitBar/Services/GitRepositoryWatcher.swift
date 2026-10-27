import Foundation

nonisolated final class GitRepositoryWatcher: @unchecked Sendable {
    let onChange: @Sendable () -> Void
    private var sources: [DispatchSourceFileSystemObject] = []
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.5
    private let queue = DispatchQueue(label: "com.gitbar.repository-watcher")
    private let queueKey = DispatchSpecificKey<Bool>()

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
        queue.setSpecific(key: queueKey, value: true)
    }

    func start(repoPath: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self._stop()
            let gitURL = URL(fileURLWithPath: repoPath).appendingPathComponent(".git")
            let subpaths = ["", "HEAD", "refs", "refs/heads", "refs/stash", "refs/tags", "worktrees"]
            let pathsToWatch = subpaths.map { gitURL.appendingPathComponent($0).path }
            for path in pathsToWatch {
                guard FileManager.default.fileExists(atPath: path) else { continue }
                let fd = open(path, O_EVTONLY)
                guard fd >= 0 else { continue }
                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .rename, .delete],
                    queue: self.queue
                )
                source.setEventHandler { [weak self] in self?.scheduleRefresh() }
                source.setCancelHandler { close(fd) }
                source.resume()
                self.sources.append(source)
            }
        }
    }

    func stop() {
        if DispatchQueue.getSpecific(key: queueKey) == true {
            _stop()
        } else {
            queue.sync { _stop() }
        }
    }

    private func _stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        sources.forEach { $0.cancel() }
        sources.removeAll()
    }

    private func scheduleRefresh() {
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        debounceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }

    deinit {
        _stop()
    }
}
