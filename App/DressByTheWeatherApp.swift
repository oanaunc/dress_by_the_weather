import SwiftUI

@main struct DressByTheWeatherApp: App {
    @State private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView().environment(model)
                .tint(Theme.ink)
                .preferredColorScheme(.light)
        }
    }
}
