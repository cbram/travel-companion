import Foundation
import UIKit
import CoreData

/// Performance Monitor für die Überwachung und Behebung von Performance-Problemen
@MainActor
class PerformanceMonitor: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PerformanceMonitor()
    
    // MARK: - Published Properties
    @Published var currentMemoryUsage: Double = 0.0
    @Published var isPerformanceWarning: Bool = false
    @Published var lastPerformanceIssue: String?
    
    // MARK: - Private Properties
    private var performanceTimer: Timer?
    private var hangDetectionTimer: Timer?
    private var lastMainThreadActivity: Date = Date()
    private var timeoutCounts: [String: Int] = [:]
    private var performanceIssues: [PerformanceIssue] = []
    
    // MARK: - Performance Issue Types
    struct PerformanceIssue {
        let type: IssueType
        let description: String
        let timestamp: Date
        let severity: Severity
        
        enum IssueType {
            case resultAccumulatorTimeout
            case mainThreadHang
            case excessiveMemoryUsage
            case coreDataPerformance
            case locationUpdateFlood
        }
        
        enum Severity {
            case low, medium, high, critical
        }
    }
    
    // MARK: - Initialization
    private init() {
        startPerformanceMonitoring()
        DebugLogger.shared.info("🔍 PerformanceMonitor initialisiert")
    }
    
    // MARK: - Performance Monitoring
    
    private func startPerformanceMonitoring() {
        // Memory Usage Monitor (alle 5 Sekunden)
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
                self?.checkPerformanceWarnings()
            }
        }
        
        // Main Thread Hang Detection (alle 100ms) - FIXED für Concurrency
        hangDetectionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.detectMainThreadHang()
            }
        }
    }
    
    @MainActor
    private func updateMemoryUsage() {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryUsageBytes = Double(memoryInfo.resident_size)
            currentMemoryUsage = memoryUsageBytes / 1024.0 / 1024.0 // Convert to MB
            
            // Warnung bei hohem Memory Usage
            if currentMemoryUsage > 200.0 {
                recordPerformanceIssue(.excessiveMemoryUsage, 
                                     description: "Memory Usage: \(String(format: "%.1f", currentMemoryUsage)) MB", 
                                     severity: currentMemoryUsage > 300.0 ? .critical : .high)
            }
        }
    }
    
    @MainActor
    private func detectMainThreadHang() async {
        let now = Date()
        let timeSinceLastActivity = now.timeIntervalSince(lastMainThreadActivity)
        
        // Update last activity timestamp
        lastMainThreadActivity = Date()
        
        // Wenn Main Thread > 0.5s nicht aktiv war
        if timeSinceLastActivity > 0.5 {
            recordPerformanceIssue(.mainThreadHang, 
                                 description: "Main Thread Hang: \(String(format: "%.2f", timeSinceLastActivity))s", 
                                 severity: timeSinceLastActivity > 1.0 ? .critical : .high)
        }
    }
    
    // MARK: - Issue Recording
    
    func recordResultAccumulatorTimeout(operation: String, timeout: TimeInterval) {
        let key = "timeout_\(operation)"
        timeoutCounts[key, default: 0] += 1
        
        let issue = PerformanceIssue(
            type: .resultAccumulatorTimeout,
            description: "Result Accumulator Timeout: \(operation) (\(String(format: "%.3f", timeout))s) - Count: \(timeoutCounts[key]!)",
            timestamp: Date(),
            severity: timeoutCounts[key]! > 5 ? .critical : .high
        )
        
        recordPerformanceIssue(issue)
        
        // Automatische Fixes versuchen
        if timeoutCounts[key]! > 5 {
            attemptTimeoutFix(for: operation)
        }
    }
    
    func recordCoreDataPerformance(operation: String, duration: TimeInterval) {
        if duration > 0.5 {
            recordPerformanceIssue(.coreDataPerformance, 
                                 description: "Slow Core Data \(operation): \(String(format: "%.3f", duration))s", 
                                 severity: duration > 2.0 ? .critical : .high)
        }
    }
    
    func recordLocationUpdateFlood(updateCount: Int, timeWindow: TimeInterval) {
        if updateCount > 10 && timeWindow < 60.0 {
            recordPerformanceIssue(.locationUpdateFlood, 
                                 description: "Location Update Flood: \(updateCount) updates in \(String(format: "%.1f", timeWindow))s", 
                                 severity: .high)
        }
    }
    
    // MARK: - Private Issue Recording
    
    private func recordPerformanceIssue(_ type: PerformanceIssue.IssueType, description: String, severity: PerformanceIssue.Severity) {
        let issue = PerformanceIssue(type: type, description: description, timestamp: Date(), severity: severity)
        recordPerformanceIssue(issue)
    }
    
    private func recordPerformanceIssue(_ issue: PerformanceIssue) {
        performanceIssues.append(issue)
        
        // Nur die letzten 50 Issues behalten
        if performanceIssues.count > 50 {
            performanceIssues.removeFirst(performanceIssues.count - 50)
        }
        
        // UI Update
        isPerformanceWarning = issue.severity == .high || issue.severity == .critical
        lastPerformanceIssue = issue.description
        
        // Logging basierend auf Severity
        switch issue.severity {
        case .low:
            DebugLogger.shared.debug("🔍 Performance: \(issue.description)")
        case .medium:
            DebugLogger.shared.info("⚠️ Performance: \(issue.description)")
        case .high:
            DebugLogger.shared.warning("🚨 Performance Warning: \(issue.description)")
        case .critical:
            DebugLogger.shared.error("🔥 CRITICAL Performance Issue: \(issue.description)")
            
            // Bei kritischen Issues automatische Cleanup-Maßnahmen
            performEmergencyCleanup()
        }
    }
    
    // MARK: - Performance Checks
    
    private func checkPerformanceWarnings() {
        let recentIssues = performanceIssues.filter { 
            Date().timeIntervalSince($0.timestamp) < 60.0 
        }
        
        let criticalIssues = recentIssues.filter { $0.severity == .critical }
        let highIssues = recentIssues.filter { $0.severity == .high }
        
        if criticalIssues.count > 0 {
            DebugLogger.shared.error("🚨 \(criticalIssues.count) kritische Performance-Issues in der letzten Minute!")
            performEmergencyCleanup()
        } else if highIssues.count > 3 {
            DebugLogger.shared.warning("⚠️ \(highIssues.count) Performance-Warnungen in der letzten Minute")
            performPreventiveCleanup()
        }
    }
    
    // MARK: - Automatic Fixes
    
    private func attemptTimeoutFix(for operation: String) {
        DebugLogger.shared.info("🔧 Versuche automatischen Fix für Timeout: \(operation)")
        
        switch operation.lowercased() {
        case let op where op.contains("location"):
            fixLocationTimeouts()
        case let op where op.contains("coredata") || op.contains("memory"):
            fixCoreDataTimeouts()
        case let op where op.contains("ui") || op.contains("view"):
            fixUITimeouts()
        default:
            DebugLogger.shared.warning("🤷 Kein spezifischer Fix für: \(operation)")
        }
    }
    
    private func fixLocationTimeouts() {
        // LocationManager Performance optimieren
        DispatchQueue.main.async {
            LocationManager.shared.requestCurrentLocation()
        }
        DebugLogger.shared.info("🔧 Location Timeout Fix angewendet")
    }
    
    private func fixCoreDataTimeouts() {
        // Core Data Context zurücksetzen
        Task {
            CoreDataManager.shared.viewContext.reset()
            DebugLogger.shared.info("🔧 Core Data Context Reset angewendet")
        }
    }
    
    private func fixUITimeouts() {
        // UI-Updates forcieren
        DispatchQueue.main.async {
            // Force UI refresh - FIXED für iOS 15+ Kompatibilität
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.view.setNeedsLayout()
            }
        }
        DebugLogger.shared.info("🔧 UI Timeout Fix angewendet")
    }
    
    // MARK: - Cleanup Methods
    
    private func performEmergencyCleanup() {
        DebugLogger.shared.warning("🚨 Emergency Cleanup wird ausgeführt...")
        
        Task {
            // Memory cleanup
            await performMemoryCleanup()
            
            // Core Data cleanup
            CoreDataManager.shared.viewContext.reset()
            
            // Location Manager cleanup
            LocationManager.shared.prepareForMemoryWarning()
            
            // Clear timeout counters
            timeoutCounts.removeAll()
            
            DebugLogger.shared.info("✅ Emergency Cleanup abgeschlossen")
        }
    }
    
    private func performPreventiveCleanup() {
        Task {
            await performMemoryCleanup()
            DebugLogger.shared.info("✅ Preventive Cleanup abgeschlossen")
        }
    }
    
    private func performMemoryCleanup() async {
        // Garbage Collection forcieren
        autoreleasepool {
            // Clear caches
            URLCache.shared.removeAllCachedResponses()
            
            // Clear performance issues older than 5 minutes
            let fiveMinutesAgo = Date().addingTimeInterval(-300)
            performanceIssues.removeAll { $0.timestamp < fiveMinutesAgo }
        }
    }
    
    // MARK: - Public Methods
    
    func getPerformanceReport() -> String {
        let recentIssues = performanceIssues.filter { 
            Date().timeIntervalSince($0.timestamp) < 300 // Last 5 minutes
        }
        
        var report = "📊 Performance Report (Last 5 minutes)\n"
        report += "Memory Usage: \(String(format: "%.1f", currentMemoryUsage)) MB\n"
        report += "Issues: \(recentIssues.count)\n\n"
        
        for issue in recentIssues.suffix(10) {
            let time = DateFormatter.localizedString(from: issue.timestamp, dateStyle: .none, timeStyle: .medium)
            report += "[\(time)] \(issue.description)\n"
        }
        
        return report
    }
    
    func clearPerformanceData() {
        performanceIssues.removeAll()
        timeoutCounts.removeAll()
        isPerformanceWarning = false
        lastPerformanceIssue = nil
        DebugLogger.shared.info("🧹 Performance-Daten geleert")
    }
    
    // MARK: - Deinitializer
    
    deinit {
        performanceTimer?.invalidate()
        hangDetectionTimer?.invalidate()
    }
} 