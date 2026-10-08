import SwiftUI

@main
struct TabbyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Tabby", systemImage: "macwindow") {
            MenuContent(model: model)
        }
    }
}
