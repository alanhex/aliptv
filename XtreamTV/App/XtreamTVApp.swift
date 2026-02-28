import SwiftData
import SwiftUI

@main
struct XtreamTVApp: App {
    private let sharedModelContainer: ModelContainer
    @StateObject private var repository: IPTVRepository

    init() {
        let schema = Schema([
            Playlist.self,
            FavoriteItem.self,
            Category.self,
            Stream.self,
            Series.self,
            SeriesEpisode.self
        ])

        do {
            let container = try XtreamTVApp.makePersistentContainer(schema: schema)
            sharedModelContainer = container
            _repository = StateObject(wrappedValue: IPTVRepository(modelContext: container.mainContext))
        } catch {
            do {
                let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let fallback = try ModelContainer(for: schema, configurations: [memoryConfiguration])
                sharedModelContainer = fallback
                _repository = StateObject(wrappedValue: IPTVRepository(modelContext: fallback.mainContext))
                assertionFailure("SwiftData persistent store failed. Falling back to in-memory store: \(error)")
            } catch {
                fatalError("Unable to initialize SwiftData: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(repository)
        }
        .modelContainer(sharedModelContainer)
    }
}

private extension XtreamTVApp {
    static func makePersistentContainer(schema: Schema) throws -> ModelContainer {
        let storeURL = try persistentStoreURL()
        do {
            let configuration = ModelConfiguration("Main", schema: schema, url: storeURL, allowsSave: true, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            try removeStoreArtifacts(at: storeURL)
            let configuration = ModelConfiguration("Main", schema: schema, url: storeURL, allowsSave: true, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }

    static func persistentStoreURL() throws -> URL {
        let fileManager = FileManager.default
        guard let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let folder = appSupportDirectory.appendingPathComponent("XtreamTV", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("XtreamTV.store")
    }

    static func removeStoreArtifacts(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let siblingNames = [
            storeURL.lastPathComponent,
            "\(storeURL.lastPathComponent)-wal",
            "\(storeURL.lastPathComponent)-shm"
        ]

        for name in siblingNames {
            let artifactURL = storeURL.deletingLastPathComponent().appendingPathComponent(name)
            if fileManager.fileExists(atPath: artifactURL.path) {
                try fileManager.removeItem(at: artifactURL)
            }
        }
    }
}
