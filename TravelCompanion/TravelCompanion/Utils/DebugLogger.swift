//
//  DebugLogger.swift
//  TravelCompanion
//
//  Created by Christian Bram on 29.05.25.
//

import Foundation
import os.log
import UIKit
import CoreLocation
import CoreData

/// Zentraler Debug Logger für Development & Testing Support
class DebugLogger: ObservableObject {
    
    // MARK: - Singleton
    static let shared = DebugLogger()
    
    // MARK: - Log Level
    enum LogLevel: Int, CaseIterable {
        case silent = 0
        case error = 1
        case warning = 2
        case info = 3
        case debug = 4
        case verbose = 5
        
        var description: String {
            switch self {
            case .silent: return "SILENT"
            case .error: return "ERROR"
            case .warning: return "WARNING"
            case .info: return "INFO"
            case .debug: return "DEBUG"
            case .verbose: return "VERBOSE"
            }
        }
        
        var emoji: String {
            switch self {
            case .silent: return "🔇"
            case .error: return "❌"
            case .warning: return "⚠️"
            case .info: return "ℹ️"
            case .debug: return "🐛"
            case .verbose: return "🔍"
            }
        }
    }
    
    // MARK: - Properties
    @Published var logLevel: LogLevel = .info
    @Published var logs: [LogEntry] = []
    @Published var performanceMetrics: [PerformanceMetric] = []
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TravelCompanion", category: "Debug")
    private let maxLogEntries = 1000
    private let logQueue = DispatchQueue(label: "com.travelcompanion.debug", qos: .utility)
    
    // MARK: - Log Entry
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let message: String
        let file: String
        let function: String
        let line: Int
        
        var formattedMessage: String {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss.SSS"
            
            return "\(timeFormatter.string(from: timestamp)) \(level.emoji) [\(file):\(line)] \(message)"
        }
    }
    
    // MARK: - Performance Metric
    struct PerformanceMetric: Identifiable {
        let id = UUID()
        let name: String
        let startTime: Date
        let endTime: Date
        let duration: TimeInterval
        let metadata: [String: Any]
        
        var formattedDuration: String {
            if duration < 1.0 {
                return String(format: "%.1fms", duration * 1000)
            } else {
                return String(format: "%.2fs", duration)
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        #if DEBUG
        logLevel = .verbose
        #else
        logLevel = .warning
        #endif
        
        log("🚀 DebugLogger initialisiert - Log Level: \(logLevel.description)", level: .info)
    }
    
    // MARK: - Logging Methods
    
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        guard level.rawValue <= logLevel.rawValue else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logEntry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            file: fileName,
            function: function,
            line: line
        )
        
        logQueue.async {
            // Console Output
            print(logEntry.formattedMessage)
            
            // OS Logger
            switch level {
            case .error:
                self.logger.error("\(message)")
            case .warning:
                self.logger.warning("\(message)")
            case .info:
                self.logger.info("\(message)")
            case .debug, .verbose:
                self.logger.debug("\(message)")
            case .silent:
                break
            }
            
            // UI Logs speichern
            DispatchQueue.main.async {
                self.logs.append(logEntry)
                
                // Alte Logs entfernen
                if self.logs.count > self.maxLogEntries {
                    self.logs.removeFirst(self.logs.count - self.maxLogEntries)
                }
            }
        }
    }
    
    // Convenience Methods
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .verbose, file: file, function: function, line: line)
    }
    
    // MARK: - Performance Monitoring
    
    func startPerformanceTimer(name: String, metadata: [String: Any] = [:]) -> UUID {
        let id = UUID()
        
        logQueue.async {
            DispatchQueue.main.async {
                // Dummy entry für Start Time
                let _ = PerformanceMetric(
                    name: name,
                    startTime: Date(),
                    endTime: Date(),
                    duration: 0,
                    metadata: metadata
                )
                
                // Store temporarily with ID
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "perfTimer_\(id.uuidString)")
                UserDefaults.standard.set(name, forKey: "perfName_\(id.uuidString)")
            }
        }
        
        verbose("⏱️ Performance Timer gestartet: \(name)")
        return id
    }
    
    func stopPerformanceTimer(id: UUID, metadata: [String: Any] = [:]) {
        guard let startTimeInterval = UserDefaults.standard.object(forKey: "perfTimer_\(id.uuidString)") as? TimeInterval,
              let name = UserDefaults.standard.string(forKey: "perfName_\(id.uuidString)") else {
            warning("Performance Timer nicht gefunden: \(id)")
            return
        }
        
        let startTime = Date(timeIntervalSince1970: startTimeInterval)
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        let metric = PerformanceMetric(
            name: name,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            metadata: metadata
        )
        
        DispatchQueue.main.async {
            self.performanceMetrics.append(metric)
            
            // Alte Metrics entfernen
            if self.performanceMetrics.count > 100 {
                self.performanceMetrics.removeFirst(self.performanceMetrics.count - 100)
            }
        }
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "perfTimer_\(id.uuidString)")
        UserDefaults.standard.removeObject(forKey: "perfName_\(id.uuidString)")
        
        let performanceLevel: LogLevel = duration > 1.0 ? .warning : .verbose
        log("⏱️ Performance: \(name) - \(metric.formattedDuration)", level: performanceLevel)
    }
    
    // MARK: - Memory Monitoring
    
    func logMemoryUsage() {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemory = Double(memoryInfo.resident_size) / 1024 / 1024 // MB
            verbose("🧠 Memory Usage: \(String(format: "%.1f", usedMemory)) MB")
        }
    }
    
    // MARK: - Location Debugging
    
    func logLocation(_ location: CLLocation, context: String = "") {
        let accuracy = location.horizontalAccuracy
        let speed = location.speed
        
        let contextStr = context.isEmpty ? "" : " [\(context)]"
        verbose("📍 Location\(contextStr): \(location.coordinate.latitude), \(location.coordinate.longitude) (±\(Int(accuracy))m, \(String(format: "%.1f", speed))m/s)")
    }
    
    func logLocationError(_ error: Error, context: String = "") {
        let contextStr = context.isEmpty ? "" : " [\(context)]"
        self.error("📍 Location Error\(contextStr): \(error.localizedDescription)")
    }
    
    // MARK: - Core Data Debugging
    
    func logCoreDataOperation(_ operation: String, entityName: String, result: Result<Void, Error>) {
        switch result {
        case .success:
            debug("💾 Core Data \(operation): \(entityName) - Erfolg")
        case .failure(let error):
            self.error("💾 Core Data \(operation): \(entityName) - Fehler: \(error.localizedDescription)")
        }
    }
    
    func logCoreDataContext(_ context: NSManagedObjectContext, operation: String) {
        let insertedCount = context.insertedObjects.count
        let updatedCount = context.updatedObjects.count
        let deletedCount = context.deletedObjects.count
        
        if insertedCount > 0 || updatedCount > 0 || deletedCount > 0 {
            debug("💾 Core Data \(operation): +\(insertedCount) ~\(updatedCount) -\(deletedCount)")
        }
    }
    
    // MARK: - Network Debugging
    
    func logNetworkRequest(url: String, method: String, statusCode: Int? = nil, duration: TimeInterval? = nil) {
        var message = "🌐 \(method) \(url)"
        
        if let statusCode = statusCode {
            let statusEmoji = statusCode < 300 ? "✅" : "❌"
            message += " - \(statusEmoji) \(statusCode)"
        }
        
        if let duration = duration {
            message += " (\(String(format: "%.2f", duration))s)"
        }
        
        let level: LogLevel = statusCode != nil && statusCode! >= 400 ? .warning : .debug
        log(message, level: level)
    }
    
    // MARK: - Photo Debugging
    
    func logPhotoOperation(_ operation: String, filename: String, fileSize: Int64? = nil, result: Result<Void, Error>) {
        var message = "📸 Photo \(operation): \(filename)"
        
        if let fileSize = fileSize {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            message += " (\(formatter.string(fromByteCount: fileSize)))"
        }
        
        switch result {
        case .success:
            message += " - Erfolg"
            debug(message)
        case .failure(let photoError):
            message += " - Fehler: \(photoError.localizedDescription)"
            self.error(message)
        }
    }
    
    // MARK: - Background Task Debugging
    
    func logBackgroundTask(_ taskName: String, timeRemaining: TimeInterval, status: String) {
        let level: LogLevel = timeRemaining < 30 ? .warning : .debug
        log("⏰ Background Task '\(taskName)': \(status) (⏱️ \(String(format: "%.1f", timeRemaining))s)", level: level)
    }
    
    // MARK: - UI Performance Monitoring
    
    func logUIThreadBlocking(operation: String, duration: TimeInterval) {
        let level: LogLevel = duration > 0.1 ? .warning : .debug
        let emoji = duration > 0.5 ? "🚨" : duration > 0.1 ? "⚠️" : "ℹ️"
        log("\(emoji) UI Thread Blocking: \(operation) - \(String(format: "%.3f", duration))s", level: level)
    }
    
    func logResultAccumulatorTimeout(operation: String, timeout: TimeInterval) {
        // PERFORMANCE-OPTIMIERUNG: Verhindere log-flooding
        let key = "lastTimeoutLog_\(operation)"
        let lastLogTime = UserDefaults.standard.double(forKey: key)
        let now = Date().timeIntervalSince1970
        
        // Nur alle 10 Sekunden für die gleiche Operation loggen
        guard now - lastLogTime > 10.0 else { return }
        
        UserDefaults.standard.set(now, forKey: key)
        warning("⏰ Result Accumulator Timeout: \(operation) - \(String(format: "%.3f", timeout))s")
        
        // Prüfe auf wiederholte Timeouts
        let timeoutCount = UserDefaults.standard.integer(forKey: "timeoutCount_\(operation)") + 1
        UserDefaults.standard.set(timeoutCount, forKey: "timeoutCount_\(operation)")
        
        if timeoutCount > 5 {
            error("🚨 KRITISCH: \(timeoutCount) Timeouts für '\(operation)' - mögliche Endlosschleife!")
        }
    }
    
    func logFrameDimensionError(view: String, width: CGFloat, height: CGFloat) {
        error("📐 Invalid Frame Dimension: \(view) - width: \(width), height: \(height)")
    }
    
    func logAutoLayoutConflict(constraint: String, view: String) {
        warning("🔧 AutoLayout Conflict: \(constraint) in \(view)")
    }
    
    // MARK: - Performance Warning Detection
    
    func checkPerformanceWarnings() {
        // OPTIMIERT: Reduziere Performance-Checks
        let now = Date()
        if let lastCheck = UserDefaults.standard.object(forKey: "lastPerformanceCheck") as? Date,
           now.timeIntervalSince(lastCheck) < 30.0 { // Max alle 30 Sekunden
            return
        }
        
        UserDefaults.standard.set(now, forKey: "lastPerformanceCheck")
        
        // Check for recent timeouts
        let recentTimeouts = performanceMetrics.filter { metric in
            metric.name.contains("timeout") && 
            Date().timeIntervalSince(metric.endTime) < 60 // Last minute
        }
        
        if recentTimeouts.count > 5 {
            warning("🚨 Performance Warning: \(recentTimeouts.count) timeouts in der letzten Minute")
            
            // Reset timeout counters nach Warnung
            DispatchQueue.global(qos: .background).async {
                let keys = UserDefaults.standard.dictionaryRepresentation().keys
                for key in keys where key.hasPrefix("timeoutCount_") {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
        
        // Check for UI blocking
        let recentUIBlocking = performanceMetrics.filter { metric in
            metric.name.contains("UI") && 
            metric.duration > 0.1 &&
            Date().timeIntervalSince(metric.endTime) < 30 // Last 30 seconds
        }
        
        if recentUIBlocking.count > 3 {
            warning("🚨 Performance Warning: \(recentUIBlocking.count) UI-Blocking Events in den letzten 30 Sekunden")
        }
    }
    
    // MARK: - Log Management
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.info("🧹 Debug Logs geleert")
        }
    }
    
    func clearPerformanceMetrics() {
        DispatchQueue.main.async {
            self.performanceMetrics.removeAll()
            self.info("🧹 Performance Metrics geleert")
        }
    }
    
    func exportLogs() -> String {
        return logs.map { $0.formattedMessage }.joined(separator: "\n")
    }
    
    func exportPerformanceMetrics() -> String {
        return performanceMetrics.map { metric in
            "\(metric.name): \(metric.formattedDuration)"
        }.joined(separator: "\n")
    }
    
    // MARK: - Log Level Management
    
    func setLogLevel(_ level: LogLevel) {
        logLevel = level
        info("🔧 Log Level geändert zu: \(level.description)")
    }
    
    // MARK: - System Info Logging
    
    func logSystemInfo() {
        let device = UIDevice.current
        let bundle = Bundle.main
        
        info("📱 Device: \(device.model) (\(device.systemName) \(device.systemVersion))")
        info("📦 App: \(bundle.displayName ?? "Unknown") v\(bundle.version ?? "Unknown") (\(bundle.buildNumber ?? "Unknown"))")
        
        // Battery Info
        device.isBatteryMonitoringEnabled = true
        let batteryLevel = device.batteryLevel
        let batteryState = device.batteryState
        
        if batteryLevel >= 0 {
            info("🔋 Battery: \(Int(batteryLevel * 100))% (\(batteryState.description))")
        }
        
        // Storage Info
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let resourceValues = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
                if let available = resourceValues.volumeAvailableCapacity,
                   let total = resourceValues.volumeTotalCapacity {
                    let usedGB = Double(total - available) / 1_000_000_000
                    let totalGB = Double(total) / 1_000_000_000
                    info("💾 Storage: \(String(format: "%.1f", usedGB))GB / \(String(format: "%.1f", totalGB))GB")
                }
            } catch {
                warning("Storage Info nicht verfügbar: \(error.localizedDescription)")
            }
        }
        
        logMemoryUsage()
    }
}

// MARK: - Extensions

extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
               object(forInfoDictionaryKey: "CFBundleName") as? String
    }
    
    var version: String? {
        return object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
    
    var buildNumber: String? {
        return object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}

extension UIDevice.BatteryState {
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }
}

extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Authorized Always"
        case .authorizedWhenInUse: return "Authorized When In Use"
        @unknown default: return "Unknown"
        }
    }
} 