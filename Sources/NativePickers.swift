import SwiftUI
import UniformTypeIdentifiers

struct ArchiveDocumentPicker: UIViewControllerRepresentable {
    enum Mode { case files, folder, export(URL) }
    let mode: Mode
    let onPick: ([URL]) -> Void
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller: UIDocumentPickerViewController
        switch mode {
        case .files:
            let extensions = ["rar"] + (0...999).map { "r" + String(format: "%02d", $0) }
            let types = extensions.compactMap { UTType(filenameExtension: $0) }
            controller = UIDocumentPickerViewController(forOpeningContentTypes: types.isEmpty ? [.data] : types, asCopy: false)
            controller.allowsMultipleSelection = true
        case .folder:
            controller = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        case .export(let url):
            controller = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        }
        controller.delegate = context.coordinator
        controller.shouldShowFileExtensions = true
        return controller
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        let onFinish: () -> Void

        init(onPick: @escaping ([URL]) -> Void, onFinish: @escaping () -> Void) {
            self.onPick = onPick
            self.onFinish = onFinish
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
            onFinish()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFinish()
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
