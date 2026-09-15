import SwiftUI

@main
struct MarkLookApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 560, minHeight: 440)
        }
        .windowResizability(.contentSize)
    }
}
