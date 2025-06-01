//
//  AppStateManager.swift
//  TravelCompanion
//
//  Created by Christian Bram on 29.05.25.
//

import Foundation
import SwiftUI
import BackgroundTasks
import UserNotifications
import CoreData
import UIKit

/// Zentraler Manager für App Lifecycle Management und Background Tasks
class AppStateManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AppStateManager()
    
    // MARK: - Published Properties
    @Published var appState: AppState = .inactive
    @Published var backgroundTimeRemaining: TimeInterval = 0
    @Published var isBackgroundProcessingEnabled = true
    
    // MARK: - Private Properties
    private let persistenceController = PersistenceController.shared
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTimer: Timer?
    
    // Background Task Identifiers
    private let locationSyncTaskID = "com.travelcompanion.location-sync"
    private let dataProcessingTaskID = "com.travelcompanion.data-processing"
    
    // MARK: - App State Enum
    enum AppState {
        case launching
        case active
        case inactive
        case background
        case terminating
        
        var description: String {
            switch self {
            case .launching: return "Startet"
            case .active: return "Aktiv"
            case .inactive: return "Inaktiv"
            case .background: return "Hintergrund"
            case .terminating: return "Beendet"
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        appState = .launching
        DebugLogger.shared.log("🔄 AppStateManager initialisiert")
    }
    
    // MARK: - Background Task Registration
    
    func registerBackgroundTasks() {
        // Location Sync Background Task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: locationSyncTaskID, using: nil) { task in
            self.handleLocationSyncBackgroundTask(task as! BGAppRefreshTask)
        }
        
        // Data Processing Background Task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: dataProcessingTaskID, using: nil) { task in
            self.handleDataProcessingBackgroundTask(task as! BGProcessingTask)
        }
        
        DebugLogger.shared.log("✅ Background Tasks registriert")
    }
    
    // MARK: - App Lifecycle Handlers
    
    func handleAppWillResignActive() {
        DebugLogger.shared.log("📱 App wird inaktiv")
        appState = .inactive
        
        // Sofortiges Speichern wichtiger Daten
        saveCoreDataContext()
        
        // LocationManager über State Change informieren
        LocationManager.shared.handleAppStateChange(.inactive)
    }
    
    func handleAppDidEnterBackground() {
        DebugLogger.shared.log("🌙 App geht in Hintergrund")
        appState = .background
        
        // Background Task starten
        startBackgroundTask()
        
        // Background App Refresh schedulen
        scheduleBackgroundAppRefresh()
        
        // Background Processing schedulen (wenn nötig)
        scheduleBackgroundProcessing()
        
        // LocationManager über State Change informieren
        LocationManager.shared.handleAppStateChange(.background)
        
        // Memory Warning vorbereiten
        prepareForMemoryWarning()
    }
    
    func handleAppWillEnterForeground() {
        DebugLogger.shared.log("🌅 App kommt aus Hintergrund zurück")
        
        // Background Task beenden
        endBackgroundTask()
        
        // LocationManager über State Change informieren
        LocationManager.shared.handleAppStateChange(.active)
        
        // Pending Memories verarbeiten
        Task { @MainActor in
            PhotoFileManager.shared.processOfflineQueue()
        }
    }
    
    func handleAppDidBecomeActive() {
        DebugLogger.shared.log("🔋 App wird aktiv")
        appState = .active
        
        // Location Permission Status überprüfen
        LocationManager.shared.checkPermissionStatus()
        
        // Photo File System Check
        Task { @MainActor in
            await PhotoFileManager.shared.validateFileSystem()
        }
        
        // Core Data Conflict Resolution
        resolveCoreDataConflicts()
        
        // LocationManager über State Change informieren
        LocationManager.shared.handleAppStateChange(.active)
    }
    
    func handleAppWillTerminate() {
        DebugLogger.shared.log("💀 App wird beendet")
        appState = .terminating
        
        // Finale Datenspeicherung
        saveCoreDataContext()
        
        // Offline Queue speichern
        Task { @MainActor in
            PhotoFileManager.shared.saveOfflineQueue()
        }
        
        // LocationManager über State Change informieren
        LocationManager.shared.handleAppStateChange(.terminating)
        
        // Cleanup
        cleanup()
    }
    
    // MARK: - Background Task Handlers
    
    @MainActor
    func handleBackgroundLocationSync() async {
        DebugLogger.shared.log("🗺️ Background Location Sync gestartet")
        
        // Location Updates verarbeiten
        await LocationManager.shared.processBackgroundLocationUpdates()
        
        // Pending Memories erstellen
        await LocationManager.shared.createPendingMemories()
        
        // Core Data speichern
        saveCoreDataContext()
        
        DebugLogger.shared.log("✅ Background Location Sync abgeschlossen")
    }
    
    @MainActor
    func handleBackgroundDataProcessing() async {
        DebugLogger.shared.log("⚙️ Background Data Processing gestartet")
        
        // Photo File System optimieren
        await PhotoFileManager.shared.optimizeFileSystem()
        
        // Orphaned Data cleanup
        await cleanupOrphanedData()
        
        // Memory Optimization
        await optimizeMemoryUsage()
        
        // Core Data speichern
        saveCoreDataContext()
        
        DebugLogger.shared.log("✅ Background Data Processing abgeschlossen")
    }
    
    // MARK: - Background Task Management
    
    private func startBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "TravelCompanion-BackgroundTask") {
            self.endBackgroundTask()
        }
        
        // Background Time Monitor starten
        startBackgroundTimeMonitor()
        
        DebugLogger.shared.log("⏱️ Background Task gestartet (ID: \(backgroundTask.rawValue))")
    }
    
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        
        // Background Time Monitor stoppen
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        
        DebugLogger.shared.log("⏹️ Background Task beendet")
    }
    
    private func startBackgroundTimeMonitor() {
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.backgroundTimeRemaining = UIApplication.shared.backgroundTimeRemaining
                
                // Warnung bei niedrigem Background Time
                if self.backgroundTimeRemaining < 30 && self.backgroundTimeRemaining > 0 {
                    DebugLogger.shared.log("⚠️ Background Time niedrig: \(self.backgroundTimeRemaining)s")
                    
                    // Emergency Save
                    self.saveCoreDataContext()
                }
            }
        }
    }
    
    // MARK: - Background App Refresh Scheduling
    
    private func scheduleBackgroundAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: locationSyncTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 Minuten
        
        do {
            try BGTaskScheduler.shared.submit(request)
            DebugLogger.shared.log("📋 Background App Refresh geplant")
        } catch {
            DebugLogger.shared.log("❌ Background App Refresh Scheduling Fehler: \(error.localizedDescription)")
        }
    }
    
    private func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: dataProcessingTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 Stunde
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            DebugLogger.shared.log("📋 Background Processing geplant")
        } catch {
            DebugLogger.shared.log("❌ Background Processing Scheduling Fehler: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Background Task Implementations
    
    private func handleLocationSyncBackgroundTask(_ task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await handleBackgroundLocationSync()
            task.setTaskCompleted(success: true)
        }
    }
    
    private func handleDataProcessingBackgroundTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await handleBackgroundDataProcessing()
            task.setTaskCompleted(success: true)
        }
    }
    
    // MARK: - Core Data Management
    
    private func saveCoreDataContext() {
        let context = persistenceController.container.viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            DebugLogger.shared.log("💾 Core Data Context gespeichert")
        } catch {
            DebugLogger.shared.log("❌ Core Data Save Fehler: \(error.localizedDescription)")
        }
    }
    
    private func resolveCoreDataConflicts() {
        let context = persistenceController.container.viewContext
        
        // Merge Policy für Conflict Resolution
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Refresh alle Objekte
        context.refreshAllObjects()
        
        DebugLogger.shared.log("🔄 Core Data Conflicts resolved")
    }
    
    // MARK: - Memory Management
    
    private func prepareForMemoryWarning() {
        // Cache leeren
        ImageCache.shared.clearCache()
        
        // Nicht essentielle Objekte freigeben
        LocationManager.shared.prepareForMemoryWarning()
        
        DebugLogger.shared.log("🧹 Memory Warning Vorbereitung abgeschlossen")
    }
    
    private func optimizeMemoryUsage() async {
        // Photo Cache optimieren
        await PhotoFileManager.shared.optimizePhotoCache()
        
        // Core Data Faults triggern für nicht genutzte Objekte
        let context = persistenceController.container.viewContext
        context.refreshAllObjects()
        
        DebugLogger.shared.log("🧹 Memory Usage optimiert")
    }
    
    // MARK: - Data Cleanup
    
    private func cleanupOrphanedData() async {
        let context = persistenceController.container.newBackgroundContext()
        
        await context.perform {
            do {
                // Orphaned Photos löschen
                let orphanedPhotosRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
                orphanedPhotosRequest.predicate = NSPredicate(format: "memory == nil")
                
                let orphanedPhotos = try context.fetch(orphanedPhotosRequest)
                for photo in orphanedPhotos {
                    // Lokale Datei löschen
                    if let localURL = photo.localURL {
                        Task { @MainActor in
                            PhotoFileManager.shared.deletePhotoFile(at: localURL)
                        }
                    }
                    context.delete(photo)
                }
                
                // Orphaned Memories ohne Trip löschen
                let orphanedMemoriesRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
                orphanedMemoriesRequest.predicate = NSPredicate(format: "trip == nil")
                
                let orphanedMemories = try context.fetch(orphanedMemoriesRequest)
                for memory in orphanedMemories {
                    context.delete(memory)
                }
                
                try context.save()
                DebugLogger.shared.log("🧹 Orphaned Data cleanup abgeschlossen")
            } catch {
                DebugLogger.shared.log("❌ Orphaned Data cleanup Fehler: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Notification Permission
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    DebugLogger.shared.log("✅ Notification Permission gewährt")
                } else {
                    DebugLogger.shared.log("❌ Notification Permission verweigert")
                }
            }
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        endBackgroundTask()
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        DebugLogger.shared.log("🧹 AppStateManager Cleanup abgeschlossen")
    }
    
    deinit {
        cleanup()
    }
} 