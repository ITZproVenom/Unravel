
    func extractSelected() {
        extract(password: archivePassword)
    }

    private func extract(password: String?) {
        guard let snapshot, let access, !selection.isEmpty else {
            activeError = .invalidSelection("Select at least one file or folder to extract.")
            return
        }
        work?.cancel()
        phase = .extracting
        activeError = nil
        currentFilename = ""
        let extractionProgress = Progress(totalUnitCount: 1)
        progress = extractionProgress
        let identifier = session
        let selected = selection
        work = Task { [weak self] in
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try ArchiveService().extract(snapshot: snapshot, selected: selected, password: password,
                                                 access: access, progress: extractionProgress,
                                                 onFileStart: { name in
                        Task { @MainActor [weak self] in
                            guard self?.session == identifier else { return }
                            self?.currentFilename = name
                        }
                    })
                }.value
                guard let self, self.session == identifier else {
                    Task.detached { ArchiveService().cleanup(result) }
                    return
                }
                self.extraction = result
                self.phase = .success
            } catch {
                self?.handle(error, identifier: identifier, retry: .extraction)
            }
        }
    }

    func cancelExtraction() {
        guard phase == .extracting else { return }
        progress.cancel()
        currentFilename = "Cancelling and removing partial files..."
    }

    func submitPassword() {
        guard !passwordInput.isEmpty else { return }
        let password = passwordInput
        passwordInput = ""
        showingPasswordPrompt = false
        switch retryOperation {
        case .loading: loadExisting(password: password)
        case .extraction:
            archivePassword = password
            extract(password: password)
        }
    }

    func cancelPasswordPrompt() {
        passwordInput = ""
        showingPasswordPrompt = false
    }

    func isSelected(_ node: ArchiveNode) -> Bool {
        let identifiers = node.descendantEntries.map(\.id)
        return !identifiers.isEmpty && identifiers.allSatisfy { selection.contains($0) }
    }

    func toggle(_ node: ArchiveNode) {
        let identifiers = node.descendantEntries.map(\.id)
        guard !identifiers.isEmpty else { return }
        if isSelected(node) {
            selection.subtract(identifiers)
        } else {
            selection.formUnion(identifiers)
        }
    }

    func selectAll() {
        selection = Set(snapshot?.entries.map(\.id) ?? [])
    }

    func deselectAll() {
        selection.removeAll()
    }

    func finishExport() {
        guard phase == .success else { return }
        if let extraction {
            let result = extraction
            self.extraction = nil
            Task.detached { ArchiveService().cleanup(result) }
        }
        phase = .ready
        currentFilename = ""
        progress = Progress(totalUnitCount: 1)
    }

    func closeArchive() {
        resetSession()
        phase = .empty
    }

    private func resetSession() {
        work?.cancel()
        progress.cancel()
        session = UUID()
        if let extraction {
            let result = extraction
            Task.detached { ArchiveService().cleanup(result) }
        }
        extraction = nil
        snapshot = nil
        roots = []
        selection = []
        searchText = ""
        activeError = nil
        currentFilename = ""
        archivePassword = nil
        volumeSet = nil
        access = nil
        passwordInput = ""
        showingPasswordPrompt = false
        progress = Progress(totalUnitCount: 1)
    }

    private func handle(_ error: Error, identifier: UUID, retry: RetryOperation) {
        guard session == identifier else { return }
        let mapped = ArchiveError.map(error, cancelled: progress.isCancelled)
        activeError = mapped
        phase = snapshot == nil ? .empty : .ready
        retryOperation = retry
        if (mapped == .passwordRequired || mapped == .badPassword), volumeSet != nil {
            showingPasswordPrompt = true
        }
    }
}
