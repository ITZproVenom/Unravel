
private struct ArchiveLoadingView: View {
    let title: String
    var body: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text("Opening \(title)").font(.headline).multilineTextAlignment(.center)
            Text("Reading the archive on a background thread. Large archives can take a moment.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct ExtractionProgressView: View {
    @ObservedObject var model: ArchiveViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.up.bin")
                .font(.system(size: 52)).foregroundStyle(Color.unravelAmber)
                .accessibilityHidden(true)
            Text("Extracting selected items").font(.title2.bold())
            ProgressView(value: Double(model.progress.completedUnitCount),
                         total: Double(max(model.progress.totalUnitCount, 1)))
                .progressViewStyle(.linear)
                .accessibilityLabel("Extraction progress")
            Text(model.currentFilename.isEmpty ? "Preparing a private temporary workspace..." : model.currentFilename)
                .font(.subheadline).foregroundStyle(.secondary)
                .lineLimit(3).multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            Button("Cancel Extraction", role: .cancel, action: model.cancelExtraction)
                .buttonStyle(.bordered)
                .disabled(model.progress.isCancelled)
        }
        .padding()
    }
}

private struct ExtractionSuccessView: View {
    let result: ExtractionResult
    @ObservedObject var model: ArchiveViewModel
    let share: () -> Void
    let export: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 30)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64)).foregroundStyle(Color.unravelAmber)
                    .accessibilityHidden(true)
                Text("Extraction complete").font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text("\(result.fileCount) files, \(ByteCountFormatter.string(fromByteCount: result.byteCount, countStyle: .file))")
                    .foregroundStyle(.secondary)
                Text("The extracted folder is kept in a private temporary workspace until you share, export, dismiss, or close this result.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                Button(action: share) {
                    Label("Share Extracted Folder", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: 340)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                Button(action: export) {
                    Label("Export to Files", systemImage: "folder.badge.plus")
                        .frame(maxWidth: 340)
                }
                .buttonStyle(.bordered).controlSize(.large)
                Button("Done", action: model.finishExport)
                    .padding(.top, 8)
                Spacer()
            }
            .padding()
        }
    }
}

private struct PasswordPromptView: View {
    @ObservedObject var model: ArchiveViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label("This archive needs a password", systemImage: "lock.fill")
                    .font(.title3.bold())
                if let error = model.activeError {
                    Text(error.errorDescription ?? "Enter the archive password.")
                        .foregroundStyle(.secondary)
                }
                SecureField("Archive password", text: $model.passwordInput)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(model.submitPassword)
                Button("Unlock Archive", action: model.submitPassword)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.passwordInput.isEmpty)
                Text("The password is used only for this archive session and is not saved.")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: model.cancelPasswordPrompt)
                }
            }
        }
    }
}

private struct ArchiveErrorView: View {
    let error: ArchiveError
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(error.errorDescription ?? "Archive operation failed", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
            if let suggestion = error.recoverySuggestion {
                Text(suggestion).font(.footnote)
            }
        }
        .foregroundStyle(Color(uiColor: .label))
        .frame(maxWidth: 560, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

private struct NoticesView: View {
    @Environment(\.dismiss) private var dismiss
    private var notices: String {
        guard let url = Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "Unravel includes UnrarKit and the UnRAR extraction library. License notices are bundled with the application."
        }
        return text
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(notices)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .navigationTitle("License Notices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
