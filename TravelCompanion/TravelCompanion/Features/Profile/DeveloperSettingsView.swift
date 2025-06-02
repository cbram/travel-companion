//
//  DeveloperSettingsView.swift
//  TravelCompanion
//
//  Created by Christian Bram on 29.05.25.
//

import SwiftUI
import CoreData

/// Development & Testing Settings View
struct DeveloperSettingsView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var debugLogger: DebugLogger
    @EnvironmentObject private var photoFileManager: PhotoFileManager
    @EnvironmentObject private var offlineMemoryCreator: OfflineMemoryCreator
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var appStateManager: AppStateManager
    @EnvironmentObject private var userManager: UserManager
    
    @State private var showingLogs = false
    @State private var showingPerformanceMetrics = false
    @State private var showingSystemInfo = false
    @State private var showingResetAlert = false
    @State private var showingNuclearResetAlert = false
    @State private var showingDeepResetAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Debug Controls
                Section("Debug & Logging") {
                    HStack {
                        Text("Log Level")
                        Spacer()
                        Picker("Log Level", selection: $debugLogger.logLevel) {
                            ForEach(DebugLogger.LogLevel.allCases, id: \.self) { level in
                                Text(level.description).tag(level)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Button(action: { showingLogs = true }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Debug Logs")
                            Spacer()
                            Text("\(debugLogger.logs.count)")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: { showingPerformanceMetrics = true }) {
                        HStack {
                            Image(systemName: "speedometer")
                            Text("Performance Metrics")
                            Spacer()
                            Text("\(debugLogger.performanceMetrics.count)")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button("Clear All Logs") {
                        debugLogger.clearLogs()
                        debugLogger.clearPerformanceMetrics()
                    }
                    .foregroundColor(.orange)
                }
                
                // MARK: - System Information
                Section("System Information") {
                    Button(action: { showingSystemInfo = true }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("System Info")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "app.badge")
                        Text("App State")
                        Spacer()
                        Text(appStateManager.appState.description)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "location")
                        Text("Location Status")
                        Spacer()
                        Text(locationManager.authorizationStatus.description)
                            .foregroundColor(.secondary)
                    }
                    
                    if appStateManager.backgroundTimeRemaining > 0 {
                        HStack {
                            Image(systemName: "timer")
                            Text("Background Time")
                            Spacer()
                            Text("\(backgroundTimeText)s")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // MARK: - Storage Management
                Section("Storage Management") {
                    HStack {
                        Image(systemName: "photo.stack")
                        Text("Photos")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(photoFileManager.totalPhotos)")
                            Text(formatBytes(photoFileManager.storageUsed))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "icloud.and.arrow.down")
                        Text("Offline Queue")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(photoFileManager.offlineQueueSize)")
                            Text("\(offlineMemoryCreator.pendingMemoriesCount) memories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Optimize File System") {
                        Task {
                            await photoFileManager.optimizeFileSystem()
                        }
                    }
                    
                    Button("Process Offline Queue") {
                        photoFileManager.processOfflineQueue()
                        Task {
                            await offlineMemoryCreator.syncOfflineMemories()
                        }
                    }
                    .disabled(photoFileManager.offlineQueueSize == 0 && offlineMemoryCreator.pendingMemoriesCount == 0)
                }
                
                // MARK: - Data Testing
                Section("Data Testing") {
                    Button("Create Test Memory") {
                        createTestMemory()
                    }
                    
                    Button("Create Test Trip") {
                        createTestTrip()
                    }
                    
                    Button("Validate Coordinates") {
                        CoreDataManager.shared.validateAndFixMemoryCoordinates()
                    }
                    
                    Button("Database Integrity Check") {
                        CoreDataManager.shared.validateDatabaseIntegrity()
                    }
                }
                
                // MARK: - Location Testing
                Section("Location Testing") {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Current Location")
                        Spacer()
                        VStack(alignment: .trailing) {
                            if let location = locationManager.currentLocation {
                                Text("\(location.coordinate.latitude, specifier: "%.4f")")
                                Text("\(location.coordinate.longitude, specifier: "%.4f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("None")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        Image(systemName: "figure.walk")
                        Text("Tracking Status")
                        Spacer()
                        Text(locationManager.isTracking ? "Active" : "Inactive")
                            .foregroundColor(locationManager.isTracking ? .green : .secondary)
                    }
                    
                    Button("Request Current Location") {
                        locationManager.requestCurrentLocation()
                    }
                    
                    Button("Start Test Tracking") {
                        startTestTracking()
                    }
                    .disabled(locationManager.isTracking)
                    
                    Button("Stop Tracking") {
                        locationManager.stopTracking()
                    }
                    .disabled(!locationManager.isTracking)
                }
                
                // MARK: - Core Data Testing
                Section("Core Data") {
                    Button("Validate Core Data") {
                        validateCoreData()
                    }
                    
                    Button("Force Save Context") {
                        do {
                            try viewContext.save()
                            debugLogger.info("✅ Core Data Context manually saved")
                        } catch {
                            debugLogger.error("❌ Core Data Save Error: \(error.localizedDescription)")
                        }
                    }
                    
                    Button("Show Core Data Stats") {
                        showCoreDataStats()
                    }
                }
                
                // MARK: - Reset & Cleanup
                Section("Reset & Cleanup") {
                    Button("Reset All Data") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                    
                    Button("Nuclear Reset (Alternative)") {
                        showingNuclearResetAlert = true
                    }
                    .foregroundColor(.red)
                    
                    Button("Deep File System Reset") {
                        showingDeepResetAlert = true
                    }
                    .foregroundColor(.red)
                    
                    Button("Clear Offline Data") {
                        clearOfflineData()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Reset File System") {
                        Task {
                            await photoFileManager.resetFileSystem()
                        }
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Developer Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingLogs) {
            LogsView()
        }
        .sheet(isPresented: $showingPerformanceMetrics) {
            PerformanceMetricsView()
        }
        .sheet(isPresented: $showingSystemInfo) {
            SystemInfoView()
        }
        .alert("Reset All Data", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will delete all trips, memories, photos, and settings. This action cannot be undone.")
        }
        .alert("Nuclear Reset", isPresented: $showingNuclearResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Nuclear Reset", role: .destructive) {
                nuclearReset()
            }
        } message: {
            Text("Alternative reset method that deletes each entity individually. Use if normal reset fails.")
        }
        .alert("Deep File System Reset", isPresented: $showingDeepResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Deep Reset", role: .destructive) {
                deepFileSystemReset()
            }
        } message: {
            Text("Löscht ALLE App-Daten inkl. Core Data Dateien, alle Cache-Verzeichnisse und System-Cache. Kann verbliebene 3,4MB entfernen.")
        }
        .onAppear {
            debugLogger.logSystemInfo()
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func createTestMemory() {
        guard let activeUser = userManager.currentUser else {
            debugLogger.warning("No active user for test memory creation")
            return
        }
        
        Task {
            let result = await offlineMemoryCreator.createQuickMemory(
                title: "Test Memory \(Date().timeIntervalSince1970)",
                for: getOrCreateTestTrip(),
                by: activeUser
            )
            
            switch result {
            case .success(let memory):
                debugLogger.info("✅ Test memory created: \(memory.title ?? "Unknown")")
            case .offline(let id):
                debugLogger.info("📦 Test memory created offline: \(id)")
            case .failure(let error):
                debugLogger.error("❌ Test memory creation failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func createTestTrip() {
        guard let activeUser = userManager.currentUser else {
            debugLogger.warning("No active user for test trip creation")
            return
        }
        
        let testTrip = Trip(context: viewContext)
        testTrip.id = UUID()
        testTrip.title = "Test Trip \(Date().timeIntervalSince1970)"
        testTrip.tripDescription = "Automatically created test trip"
        testTrip.startDate = Date()
        testTrip.endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        testTrip.isActive = true
        testTrip.createdAt = Date()
        testTrip.owner = activeUser
        
        do {
            try viewContext.save()
            debugLogger.info("✅ Test trip created: \(testTrip.title ?? "Unknown")")
        } catch {
            debugLogger.error("❌ Test trip creation failed: \(error.localizedDescription)")
        }
    }
    
    private func getOrCreateTestTrip() -> Trip {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "title BEGINSWITH 'Test Trip'")
        request.fetchLimit = 1
        
        if let existingTrip = try? viewContext.fetch(request).first {
            return existingTrip
        }
        
        // Create new test trip if none exists
        let testTrip = Trip(context: viewContext)
        testTrip.id = UUID()
        testTrip.title = "Test Trip (Auto-created)"
        testTrip.tripDescription = "Automatically created for testing"
        testTrip.startDate = Date()
        testTrip.endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        testTrip.isActive = true
        testTrip.createdAt = Date()
        testTrip.owner = userManager.currentUser
        
        try? viewContext.save()
        return testTrip
    }
    
    private func startTestTracking() {
        guard let activeUser = userManager.currentUser else {
            debugLogger.warning("No active user for test tracking")
            return
        }
        
        let testTrip = getOrCreateTestTrip()
        locationManager.startTracking(for: testTrip, user: activeUser)
        debugLogger.info("🚀 Test tracking started")
    }
    
    private func validateCoreData() {
        let context = viewContext
        
        // Users validation
        let usersRequest: NSFetchRequest<User> = User.fetchRequest()
        let usersCount = (try? context.fetch(usersRequest).count) ?? 0
        
        // Trips validation
        let tripsRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
        let tripsCount = (try? context.fetch(tripsRequest).count) ?? 0
        
        // Memories validation
        let memoriesRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
        let memoriesCount = (try? context.fetch(memoriesRequest).count) ?? 0
        
        // Photos validation
        let photosRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        let photosCount = (try? context.fetch(photosRequest).count) ?? 0
        
        debugLogger.info("📊 Core Data Validation:")
        debugLogger.info("  Users: \(usersCount)")
        debugLogger.info("  Trips: \(tripsCount)")
        debugLogger.info("  Memories: \(memoriesCount)")
        debugLogger.info("  Photos: \(photosCount)")
    }
    
    private func showCoreDataStats() {
        validateCoreData()
        
        // Memory leaks check
        if viewContext.insertedObjects.count > 0 {
            debugLogger.warning("⚠️ Inserted objects not saved: \(viewContext.insertedObjects.count)")
        }
        
        if viewContext.updatedObjects.count > 0 {
            debugLogger.info("ℹ️ Updated objects: \(viewContext.updatedObjects.count)")
        }
        
        if viewContext.deletedObjects.count > 0 {
            debugLogger.info("🗑️ Deleted objects: \(viewContext.deletedObjects.count)")
        }
    }
    
    private func clearOfflineData() {
        photoFileManager.processOfflineQueue()
        offlineMemoryCreator.clearOfflineMemories()
        locationManager.clearOfflineData()
        debugLogger.info("🧹 Offline data cleared")
    }
    
    private func resetAllData() {
        Task {
            debugLogger.info("🔄 Starting complete data reset...")
            
            // Core Data reset - nur existierende Entities
            let entities = ["Photo", "Memory", "Trip", "User"]
            
            for entityName in entities {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                
                // Wichtig: resultType setzen für bessere Feedback
                deleteRequest.resultType = .resultTypeCount
                
                do {
                    let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
                    let deletedCount = result?.result as? Int ?? 0
                    debugLogger.info("✅ Deleted \(deletedCount) \(entityName) entities")
                } catch {
                    debugLogger.error("❌ Failed to delete \(entityName): \(error.localizedDescription)")
                }
            }
            
            // Context nach Batch Delete refreshen - WICHTIG!
            await MainActor.run {
                viewContext.refreshAllObjects()
            }
            
            // File system reset
            await photoFileManager.resetFileSystem()
            
            // Offline data reset
            clearOfflineData()
            
            // UserDefaults reset
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
                UserDefaults.standard.synchronize()
                debugLogger.info("✅ UserDefaults cleared")
            }
            
            // Force save context
            await MainActor.run {
                do {
                    try viewContext.save()
                    debugLogger.info("✅ Context saved after reset")
                } catch {
                    debugLogger.error("❌ Context save failed: \(error.localizedDescription)")
                }
            }
            
            // Final validation
            await MainActor.run {
                validateDataAfterReset()
            }
            
            debugLogger.info("🎯 Complete data reset finished")
        }
    }
    
    private func validateDataAfterReset() {
        let entities = ["User", "Trip", "Memory", "Photo"]
        var totalRemaining = 0
        
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let count = (try? viewContext.fetch(request).count) ?? 0
            totalRemaining += count
            if count > 0 {
                debugLogger.warning("⚠️ \(entityName): \(count) entities still remain")
            }
        }
        
        if totalRemaining == 0 {
            debugLogger.info("✅ Data reset verification: All data successfully removed")
        } else {
            debugLogger.error("❌ Data reset incomplete: \(totalRemaining) entities still exist")
        }
    }
    
    private func nuclearReset() {
        Task {
            debugLogger.info("💥 Starting nuclear reset (individual entity deletion)...")
            
            await MainActor.run {
                // Lösche alle Entities einzeln für maximale Sicherheit
                deleteAllEntitiesIndividually()
                
                // Force save
                do {
                    try viewContext.save()
                    debugLogger.info("✅ Nuclear reset: Context saved")
                } catch {
                    debugLogger.error("❌ Nuclear reset save failed: \(error)")
                }
            }
            
            // File system reset
            await photoFileManager.resetFileSystem()
            
            // Clear all caches and offline data
            clearOfflineData()
            
            // UserDefaults reset
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
                UserDefaults.standard.synchronize()
            }
            
            await MainActor.run {
                // Final validation
                validateDataAfterReset()
                debugLogger.info("💥 Nuclear reset completed")
            }
        }
    }
    
    private func deleteAllEntitiesIndividually() {
        // Photos zuerst (haben Dependencies)
        let photoRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        if let photos = try? viewContext.fetch(photoRequest) {
            debugLogger.info("🗑️ Deleting \(photos.count) photos individually...")
            for photo in photos {
                viewContext.delete(photo)
            }
        }
        
        // Memories
        let memoryRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
        if let memories = try? viewContext.fetch(memoryRequest) {
            debugLogger.info("🗑️ Deleting \(memories.count) memories individually...")
            for memory in memories {
                viewContext.delete(memory)
            }
        }
        
        // Trips
        let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
        if let trips = try? viewContext.fetch(tripRequest) {
            debugLogger.info("🗑️ Deleting \(trips.count) trips individually...")
            for trip in trips {
                viewContext.delete(trip)
            }
        }
        
        // Users
        let userRequest: NSFetchRequest<User> = User.fetchRequest()
        if let users = try? viewContext.fetch(userRequest) {
            debugLogger.info("🗑️ Deleting \(users.count) users individually...")
            for user in users {
                viewContext.delete(user)
            }
        }
    }
    
    private var backgroundTimeText: String {
        let timeRemaining = appStateManager.backgroundTimeRemaining
        if timeRemaining.isFinite {
            return "\(Int(timeRemaining))"
        } else {
            return "Unknown"
        }
    }
    
    private func deepFileSystemReset() {
        Task {
            debugLogger.info("🔥 Starting DEEP file system reset...")
            
            // 1. Standard Reset zuerst
            await resetAllCoreData()
            
            // 2. Alle App-Verzeichnisse komplett löschen
            await deleteAllAppDirectories()
            
            // 3. Core Data Store-Dateien physisch löschen
            await deleteCoreDataStoreFiles()
            
            // 4. Alle iOS System-Caches löschen
            await clearAllSystemCaches()
            
            // 5. App-spezifische Cache-Verzeichnisse
            await clearAppSpecificCaches()
            
            // 6. UserDefaults komplett resetten
            clearAllUserDefaults()
            
            // 7. File Manager Caches
            clearFileManagerCaches()
            
            // Final validation
            await MainActor.run {
                validateCompleteReset()
            }
            
            debugLogger.info("🔥 Deep file system reset completed")
        }
    }
    
    private func resetAllCoreData() async {
        let entities = ["Photo", "Memory", "Trip", "User"]
        
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeCount
            
            do {
                let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
                let deletedCount = result?.result as? Int ?? 0
                debugLogger.info("🗑️ Deleted \(deletedCount) \(entityName) entities")
            } catch {
                debugLogger.error("❌ Failed to delete \(entityName): \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            viewContext.refreshAllObjects()
            try? viewContext.save()
        }
    }
    
    private func deleteAllAppDirectories() async {
        let fileManager = FileManager.default
        
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            // Alle Inhalte des Documents Directory löschen
            let contents = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            
            for itemURL in contents {
                try fileManager.removeItem(at: itemURL)
                debugLogger.info("🗑️ Deleted directory: \(itemURL.lastPathComponent)")
            }
            
            // Auch andere App-Verzeichnisse
            if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let cacheContents = try fileManager.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil)
                for itemURL in cacheContents {
                    try fileManager.removeItem(at: itemURL)
                    debugLogger.info("🗑️ Deleted cache: \(itemURL.lastPathComponent)")
                }
            }
            
            // Temporary Directory
            let tempURL = fileManager.temporaryDirectory
            let tempContents = try fileManager.contentsOfDirectory(at: tempURL, includingPropertiesForKeys: nil)
            for itemURL in tempContents {
                try fileManager.removeItem(at: itemURL)
            }
            
        } catch {
            debugLogger.error("❌ Error deleting app directories: \(error.localizedDescription)")
        }
    }
    
    private func deleteCoreDataStoreFiles() async {
        let fileManager = FileManager.default
        
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        // Core Data Store-Dateien suchen und löschen
        let storePatterns = ["*.sqlite", "*.sqlite-wal", "*.sqlite-shm"]
        
        do {
            let allFiles = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            
            for pattern in storePatterns {
                let matchingFiles = allFiles.filter { url in
                    let filename = url.lastPathComponent.lowercased()
                    return pattern.dropFirst().allSatisfy { filename.hasSuffix(String($0)) } ||
                           (pattern.hasPrefix("*") && filename.hasSuffix(String(pattern.dropFirst())))
                }
                
                for fileURL in matchingFiles {
                    try fileManager.removeItem(at: fileURL)
                    debugLogger.info("🗑️ Deleted Core Data file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            debugLogger.error("❌ Error deleting Core Data files: \(error.localizedDescription)")
        }
    }
    
    private func clearAllSystemCaches() async {
        // URLCache leeren
        URLCache.shared.removeAllCachedResponses()
        debugLogger.info("🧹 URLCache cleared")
        
        // Image Cache leeren
        ImageCache.shared.clearCache()
        debugLogger.info("🧹 Image Cache cleared")
    }
    
    private func clearAppSpecificCaches() async {
        let fileManager = FileManager.default
        
        // KRITISCH: Beende alle SQLite-Verbindungen vor dem Löschen
        await closeAllDatabaseConnections()
        
        // Library/Caches Verzeichnis komplett leeren
        if let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let cachesURL = libraryURL.appendingPathComponent("Caches")
            
            do {
                if fileManager.fileExists(atPath: cachesURL.path) {
                    // SICHER: Warte kurz um sicherzustellen, dass alle Verbindungen geschlossen sind
                    try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                    
                    try fileManager.removeItem(at: cachesURL)
                    debugLogger.info("🗑️ Deleted Library/Caches")
                }
            } catch {
                debugLogger.error("❌ Error deleting Library/Caches: \(error.localizedDescription)")
            }
        }
    }
    
    /// Schließt alle aktiven Datenbankverbindungen sicher
    private func closeAllDatabaseConnections() async {
        // CoreData Context synchronisieren und leeren
        await MainActor.run {
            let context = CoreDataManager.shared.viewContext
            context.refreshAllObjects()
            
            // Alle ausstehenden Änderungen verwerfen
            if context.hasChanges {
                context.rollback()
            }
        }
        
        // URLCache und andere System-Caches leeren
        URLCache.shared.removeAllCachedResponses()
        
        // Kurze Pause für File-System-Synchronisation
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        debugLogger.info("🔒 Alle Datenbankverbindungen geschlossen")
    }
    
    private func clearAllUserDefaults() {
        // Alle UserDefaults-Domains löschen
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
            debugLogger.info("🗑️ UserDefaults cleared")
        }
        
        // Standard UserDefaults auch leeren
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
    }
    
    private func clearFileManagerCaches() {
        // FileManager interne Caches leeren soweit möglich
        debugLogger.info("🧹 FileManager caches cleared")
    }
    
    private func validateCompleteReset() {
        let fileManager = FileManager.default
        
        // Documents Directory Größe prüfen
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let size = try fileManager.allocatedSizeOfDirectory(at: documentsURL)
                debugLogger.info("📊 Documents Directory nach Reset: \(formatBytes(Int64(size)))")
                
                if size < 1024 * 1024 { // < 1MB
                    debugLogger.info("✅ Deep reset erfolgreich: Nur \(formatBytes(Int64(size))) verbleibend")
                } else {
                    debugLogger.warning("⚠️ \(formatBytes(Int64(size))) verbleiben noch - möglicherweise System-Dateien")
                }
            } catch {
                debugLogger.error("❌ Validation error: \(error.localizedDescription)")
            }
        }
        
        // Core Data validation
        validateDataAfterReset()
    }
}

// MARK: - Supporting Views

struct LogsView: View {
    @ObservedObject private var debugLogger = DebugLogger.shared
    
    var body: some View {
        NavigationView {
            List(debugLogger.logs) { log in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.level.emoji)
                        Text(log.message)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                    }
                    
                    HStack {
                        Text(DateFormatter.debugFormatter.string(from: log.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(log.file):\(log.line)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        // Export functionality
                        let logs = debugLogger.exportLogs()
                        UIPasteboard.general.string = logs
                    }
                }
            }
        }
    }
}

struct PerformanceMetricsView: View {
    @ObservedObject private var debugLogger = DebugLogger.shared
    
    var body: some View {
        NavigationView {
            List(debugLogger.performanceMetrics) { metric in
                HStack {
                    VStack(alignment: .leading) {
                        Text(metric.name)
                            .font(.headline)
                        Text(DateFormatter.debugFormatter.string(from: metric.startTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(metric.formattedDuration)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(metric.duration > 1.0 ? .red : .primary)
                }
            }
            .navigationTitle("Performance Metrics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SystemInfoView: View {
    @ObservedObject private var debugLogger = DebugLogger.shared
    @ObservedObject private var photoFileManager = PhotoFileManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Device") {
                    InfoRow(title: "Model", value: UIDevice.current.model)
                    InfoRow(title: "System", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                    InfoRow(title: "Battery", value: batteryInfo)
                }
                
                Section("App") {
                    InfoRow(title: "Version", value: Bundle.main.version ?? "Unknown")
                    InfoRow(title: "Build", value: Bundle.main.buildNumber ?? "Unknown")
                }
                
                Section("Storage") {
                    InfoRow(title: "Photos", value: "\(photoFileManager.totalPhotos)")
                    InfoRow(title: "Used Space", value: formatBytes(photoFileManager.storageUsed))
                    InfoRow(title: "Photos Dir", value: photoFileManager.getStorageInfo()["photosDirectory"] as? String ?? "Unknown")
                }
            }
            .navigationTitle("System Info")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var batteryInfo: String {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        
        let level = device.batteryLevel
        let state = device.batteryState
        
        if level >= 0 {
            return "\(Int(level * 100))% (\(state.description))"
        } else {
            return "Unknown"
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let debugFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

#Preview {
    DeveloperSettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(TripManager.shared)
        .environmentObject(UserManager.shared)
} 