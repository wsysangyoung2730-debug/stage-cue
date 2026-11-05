import SwiftUI

@main
struct StageCueApp: App {
    @State private var library = CueLibrary()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(library)
                .tint(Color.accentColor)
                .preferredColorScheme(.light)
        }
    }
}
