import SwiftUI

@main
struct UnravelApp: App {
    @StateObject private var model = ArchiveViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .tint(.unravelAmber)
        }
    }
}

extension Color {
    static let unravelAmber = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.69, blue: 0.25, alpha: 1)
            : UIColor(red: 0.67, green: 0.38, blue: 0.07, alpha: 1)
    })

    static let unravelNavy = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.22, blue: 0.31, alpha: 1)
            : UIColor(red: 0.12, green: 0.18, blue: 0.27, alpha: 1)
    })
}
