import SwiftUI

@main
struct TabbyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(nsImage: MenuBarIcon.image)
        }
    }
}
