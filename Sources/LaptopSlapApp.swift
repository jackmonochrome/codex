import SwiftUI

@main
struct LaptopSlapApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
        .defaultSize(width: 700, height: 760)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        MenuBarExtra("LaptopSlap", systemImage: appModel.isListening ? "waveform.circle.fill" : "waveform.circle") {
            MenuBarContentView()
                .environmentObject(appModel)
        }
        .menuBarExtraStyle(.window)
    }
}
