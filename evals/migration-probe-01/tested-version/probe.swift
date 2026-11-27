import Foundation
import SwiftData
import CoreData

// These synthetic schemas demonstrate the test technique, not an app's release history.
enum V1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Record.self] }
    @Model final class Record {
        var id: UUID
        var title: String
        var parent: Record?
        @Relationship(inverse: \Record.parent) var children: [Record] = []
        init(id: UUID, title: String, parent: Record? = nil) {
            self.id = id; self.title = title; self.parent = parent
        }
    }
}

enum V2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Record.self] }
    @Model final class Record {
        var id: UUID
        @Attribute(originalName: "title") var name: String
        var parent: Record?
        @Relationship(inverse: \Record.parent) var children: [Record] = []
        init(id: UUID, name: String, parent: Record? = nil) {
            self.id = id; self.name = name; self.parent = parent
        }
    }
}

enum V3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    static var models: [any PersistentModel.Type] { [Record.self] }
    @Model final class Record {
        var id: UUID
        @Attribute(originalName: "title") var name: String
        var memo: String?
        var parent: Record?
        @Relationship(inverse: \Record.parent) var children: [Record] = []
        init(id: UUID, name: String, parent: Record? = nil) {
            self.id = id; self.name = name; self.parent = parent
        }
    }
}

enum Plan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [V1.self, V2.self, V3.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: V1.self, toVersion: V2.self),
         .lightweight(fromVersion: V2.self, toVersion: V3.self)]
    }
}

struct Snapshot: Codable {
    var id: String
    var name: String
    var parentID: String?
    var childrenIDs: [String]
    var memo: String?
}

enum ProbeError: Error {
    case invalidArguments
    case storeAlreadyExists
    case missingSourceStore
    case missingVersionMetadata
}

struct ProbeResult: Codable {
    var records: [Snapshot]
    var storeVersions: [String]
    var priorVersions: [String]?
}

@main struct MigrationProbe {
    static func storeVersions(at url: URL) throws -> [String] {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: url)
        if let versions = metadata[NSStoreModelVersionIdentifiersKey] as? [String], !versions.isEmpty { return versions.sorted() }
        if let versions = metadata[NSStoreModelVersionIdentifiersKey] as? Set<String>, !versions.isEmpty { return versions.sorted() }
        throw ProbeError.missingVersionMetadata
    }

    /// Each invocation owns its container on the main actor and exits before a store is copied.
    @MainActor static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 4, ["seed1", "seed2", "open2", "open3"].contains(args[1]),
              ["empty", "records"].contains(args[3]) else { throw ProbeError.invalidArguments }
        let operation = args[1]
        let url = URL(fileURLWithPath: args[2])
        let first = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let second = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let schema: Schema
        if operation == "seed1" { schema = Schema(versionedSchema: V1.self) }
        else if operation == "seed2" || operation == "open2" { schema = Schema(versionedSchema: V2.self) }
        else { schema = Schema(versionedSchema: V3.self) }
        if operation.hasPrefix("seed"), FileManager.default.fileExists(atPath: url.path) {
            throw ProbeError.storeAlreadyExists
        }
        let priorVersions: [String]?
        if operation.hasPrefix("seed") { priorVersions = nil }
        else {
            guard FileManager.default.fileExists(atPath: url.path) else { throw ProbeError.missingSourceStore }
            priorVersions = try storeVersions(at: url)
        }
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, migrationPlan: operation.hasPrefix("seed") ? nil : Plan.self,
                                           configurations: [configuration])
        let context = container.mainContext
        context.autosaveEnabled = false
        var snapshots: [Snapshot]
        if operation == "seed1" {
            if args[3] == "records" {
                let root = V1.Record(id: first, title: "Crème brûlée")
                context.insert(root)
                context.insert(V1.Record(id: second, title: "Budget 2048", parent: root))
                try context.save()
            }
            snapshots = try context.fetch(FetchDescriptor<V1.Record>()).map {
                Snapshot(id: $0.id.uuidString, name: $0.title, parentID: $0.parent?.id.uuidString, childrenIDs: $0.children.map { $0.id.uuidString }.sorted(), memo: nil)
            }
        } else if operation == "seed2" || operation == "open2" {
            if operation == "seed2", args[3] == "records" {
                let root = V2.Record(id: first, name: "Crème brûlée")
                context.insert(root)
                context.insert(V2.Record(id: second, name: "Budget 2048", parent: root))
                try context.save()
            }
            snapshots = try context.fetch(FetchDescriptor<V2.Record>()).map {
                Snapshot(id: $0.id.uuidString, name: $0.name, parentID: $0.parent?.id.uuidString, childrenIDs: $0.children.map { $0.id.uuidString }.sorted(), memo: nil)
            }
        } else {
            snapshots = try context.fetch(FetchDescriptor<V3.Record>()).map {
                Snapshot(id: $0.id.uuidString, name: $0.name, parentID: $0.parent?.id.uuidString, childrenIDs: $0.children.map { $0.id.uuidString }.sorted(), memo: $0.memo)
            }
        }
        snapshots.sort { $0.id < $1.id }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(ProbeResult(records: snapshots, storeVersions: try storeVersions(at: url), priorVersions: priorVersions)), as: UTF8.self))
    }
}
