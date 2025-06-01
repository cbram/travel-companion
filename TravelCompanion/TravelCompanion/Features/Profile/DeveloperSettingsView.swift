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
    
    @ObservedObject private var debugLogger = DebugLogger.shared
    @ObservedObject private var photoFileManager = PhotoFileManager.shared
    @ObservedObject private var offlineMemoryCreator = OfflineMemoryCreator.shared
    @ObservedObject private var appStateManager = AppStateManager.shared
    @ObservedObject private var locationManager = LocationManager.shared
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var tripManager: TripManager
    @EnvironmentObject private var userManager: UserManager
    
    @State private var showingLogs = false
    @State private var showingPerformanceMetrics = false
    @State private var showingSystemInfo = false
    @State private var isGeneratingSampleData = false
    @State private var showingResetAlert = false
    
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
                            Text("\(Int(appStateManager.backgroundTimeRemaining))s")
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
                
                // MARK: - Sample Data Generation
                Section("Sample Data") {
                    Button(action: generateSampleData) {
                        HStack {
                            if isGeneratingSampleData {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text("Generate Sample Data")
                        }
                    }
                    .disabled(isGeneratingSampleData)
                    
                    Button("Create Test Memory") {
                        createTestMemory()
                    }
                    
                    Button("Create Test Trip") {
                        createTestTrip()
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
    
    private func generateSampleData() {
        isGeneratingSampleData = true
        
        Task {
            let timerId = debugLogger.startPerformanceTimer(name: "Sample Data Generation")
            
            // Sample User erstellen
            let sampleUser = User(context: viewContext)
            sampleUser.id = UUID()
            sampleUser.email = "developer@travelcompanion.app"
            sampleUser.displayName = "Developer User"
            sampleUser.createdAt = Date()
            sampleUser.isActive = true
            
            // Sample Trips erstellen
            let tripNames = ["Berlin Exploration", "Alps Adventure", "Coastal Road Trip", "City Break Paris"]
            var trips: [Trip] = []
            
            for tripName in tripNames {
                let trip = Trip(context: viewContext)
                trip.id = UUID()
                trip.title = tripName
                trip.tripDescription = "Sample trip: \(tripName)"
                trip.startDate = Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...30), to: Date())
                trip.endDate = Calendar.current.date(byAdding: .day, value: Int.random(in: 1...7), to: trip.startDate ?? Date())
                trip.isActive = Bool.random()
                trip.createdAt = Date()
                trip.owner = sampleUser
                trips.append(trip)
            }
            
            // Sample Memories erstellen
            let memoryTitles = [
                "Beautiful Sunset", "Local Market Visit", "Mountain View", "Street Art Discovery",
                "Delicious Food", "Historic Building", "Nature Walk", "City Lights"
            ]
            
            for trip in trips {
                let memoryCount = Int.random(in: 2...5)
                for i in 0..<memoryCount {
                    let memory = Memory(context: viewContext)
                    memory.id = UUID()
                    memory.title = memoryTitles.randomElement() ?? "Sample Memory"
                    memory.content = "This is a sample memory created for testing purposes."
                    memory.latitude = 52.5 + Double.random(in: -0.5...0.5) // Around Berlin
                    memory.longitude = 13.4 + Double.random(in: -0.5...0.5)
                    memory.timestamp = Calendar.current.date(byAdding: .hour, value: -i * 3, to: Date()) ?? Date()
                    memory.createdAt = Date()
                    memory.author = sampleUser
                    memory.trip = trip
                }
            }
            
            // Core Data speichern
            do {
                try viewContext.save()
                debugLogger.stopPerformanceTimer(id: timerId)
                
                await MainActor.run {
                    isGeneratingSampleData = false
                }
                
                debugLogger.info("✅ Sample data generated successfully")
            } catch {
                debugLogger.stopPerformanceTimer(id: timerId)
                debugLogger.error("❌ Sample data generation failed: \(error.localizedDescription)")
                
                await MainActor.run {
                    isGeneratingSampleData = false
                }
            }
        }
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
            // Core Data reset
            let entities = ["User", "Trip", "Memory", "Photo"]
            for entityName in entities {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                
                do {
                    try viewContext.execute(deleteRequest)
                } catch {
                    debugLogger.error("❌ Failed to delete \(entityName): \(error.localizedDescription)")
                }
            }
            
            // File system reset
            await photoFileManager.resetFileSystem()
            
            // Offline data reset
            clearOfflineData()
            
            // Save context
            do {
                try viewContext.save()
                debugLogger.info("✅ All data reset completed")
            } catch {
                debugLogger.error("❌ Reset save failed: \(error.localizedDescription)")
            }
        }
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