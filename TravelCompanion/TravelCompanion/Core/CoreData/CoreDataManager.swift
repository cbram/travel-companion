@preconcurrency import Foundation
@preconcurrency import CoreData
@preconcurrency import UIKit

/// Zentrale Verwaltung des Core Data Stacks mit Performance-Optimierungen
@MainActor
class CoreDataManager {
    
    // MARK: - Singleton
    static let shared = CoreDataManager()
    
    // MARK: - Properties
    var lastSaveError: Error?
    
    // MARK: - Core Data Stack
    var persistentContainer: NSPersistentContainer {
        return PersistenceController.shared.container
    }
    
    // MARK: - Computed Properties
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Initialization
    private init() {
        print("✅ CoreDataManager: Using PersistenceController.shared")
        
        // NEUE Initialisierung: Bereinige ungültige Koordinaten bei App-Start
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.validateAndFixMemoryCoordinates()
        }
    }
    
    // MARK: - Core Data Saving Support
    
    @discardableResult
    func save() -> Bool {
        let context = persistentContainer.viewContext
        
        guard context.hasChanges else {
            lastSaveError = nil // Reset error bei erfolgreichem "Save" (keine Änderungen)
            return true // Kein Save nötig wenn keine Änderungen
        }
        
        // ROBUSTE Save-Operation mit Retry-Mechanismus
        var saveAttempts = 0
        let maxAttempts = 3
        var lastError: NSError?
        
        while saveAttempts < maxAttempts {
            saveAttempts += 1
            
            do {
                // Performance-Monitoring für Debug-Zwecke
                let startTime = CFAbsoluteTimeGetCurrent()
                
                // KRITISCHE Pre-Save Validierung
                let insertedObjects = context.insertedObjects
                let updatedObjects = context.updatedObjects
                
                print("💾 CoreDataManager: Save-Versuch \(saveAttempts) - \(insertedObjects.count) neue, \(updatedObjects.count) geänderte Objekte")
                
                // Validiere inserted Objects vor Save
                for object in insertedObjects {
                    if object.isDeleted {
                        print("⚠️ CoreDataManager: Gelöschtes Object in insertedObjects gefunden")
                        context.refresh(object, mergeChanges: false)
                    }
                }
                
                try context.save()
                
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                
                if timeElapsed > 0.1 { // Warnung bei > 100ms
                    print("⚠️ CoreDataManager: Langsamer Save detected: \(String(format: "%.3f", timeElapsed))s (Versuch \(saveAttempts))")
                } else {
                    print("✅ CoreDataManager: Context saved successfully (\(String(format: "%.3f", timeElapsed))s, Versuch \(saveAttempts))")
                }
                
                // POST-SAVE Validierung: Prüfe ob ObjectIDs permanent sind
                for object in insertedObjects {
                    if object.objectID.isTemporaryID {
                        print("⚠️ CoreDataManager: ObjectID noch temporär nach Save: \(object)")
                    }
                }
                
                lastSaveError = nil // Reset error bei erfolgreichem Save
                return true
                
            } catch let error as NSError {
                lastError = error
                lastSaveError = error // Setze lastSaveError für externen Zugriff
                
                print("❌ CoreDataManager: Save-Versuch \(saveAttempts) fehlgeschlagen: \(error)")
                print("❌ Error Domain: \(error.domain)")
                print("❌ Error Code: \(error.code)")
                print("❌ Localized Description: \(error.localizedDescription)")
                
                // Detaillierte Fehleranalyse
                if let conflicts = error.userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
                    print("❌ Conflicts with inserted objects: \(conflicts.count)")
                }
                if let deletedObjects = error.userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> {
                    print("❌ Issues with deleted objects: \(deletedObjects.count)")
                }
                
                // ERWEITERTE Fehlerbehandlung basierend auf Error-Code
                switch error.code {
                case NSValidationErrorMaximum, NSValidationErrorMinimum:
                    print("❌ Validation Error - keine Retry sinnvoll")
                    break // Keine Retry bei Validation Errors
                    
                case NSManagedObjectContextLockingError:
                    print("⚠️ Context Locking Error - kurze Pause und Retry")
                    if saveAttempts < maxAttempts {
                        Thread.sleep(forTimeInterval: 0.05) // 50ms Pause
                        continue
                    }
                    
                case NSCoreDataError:
                    print("⚠️ Core Data Error - Context refresh und Retry")
                    if saveAttempts < maxAttempts {
                        context.refreshAllObjects()
                        Thread.sleep(forTimeInterval: 0.1) // 100ms Pause
                        continue
                    }
                    
                default:
                    print("⚠️ Unbekannter Error - Standard Retry")
                    if saveAttempts < maxAttempts {
                        Thread.sleep(forTimeInterval: 0.1)
                        continue
                    }
                }
                
                // Wenn wir hier sind, keine weitere Retry möglich
                break
            }
        }
        
        // Alle Retry-Versuche fehlgeschlagen
        print("❌ CoreDataManager: Alle \(maxAttempts) Save-Versuche fehlgeschlagen")
        if let finalError = lastError {
            lastSaveError = finalError // Stelle sicher, dass der finale Fehler gesetzt ist
            print("❌ Final Error: \(finalError.localizedDescription)")
            
            // CONTEXT-ROLLBACK bei kritischen Fehlern
            print("🔄 CoreDataManager: Führe Context-Rollback durch...")
            context.rollback()
        }
        
        return false
    }
    
    func saveContext(context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                let startTime = CFAbsoluteTimeGetCurrent()
                try context.save()
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                
                if timeElapsed > 0.1 {
                    print("⚠️ CoreDataManager: Langsamer Background Save: \(String(format: "%.3f", timeElapsed))s")
                } else {
                    print("✅ CoreDataManager: Background context saved successfully (\(String(format: "%.3f", timeElapsed))s)")
                }
            } catch {
                print("❌ CoreDataManager: Failed to save background context: \(error)")
            }
        }
    }
    
    /// Asynchroner Save für bessere UI-Performance
    func saveAsync(completion: @escaping (Bool) -> Void = { _ in }) {
        let context = persistentContainer.viewContext
        
        guard context.hasChanges else {
            completion(true)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                try context.save()
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                
                DispatchQueue.main.async {
                    print("✅ CoreDataManager: Async save completed (\(String(format: "%.3f", timeElapsed))s)")
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ CoreDataManager: Async save failed: \(error)")
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Background Context
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - User Management
    
    @discardableResult
    func createUser(email: String, displayName: String) -> User {
        let user = User(context: viewContext)
        user.id = UUID()
        user.email = email
        user.displayName = displayName
        user.createdAt = Date()
        user.isActive = true
        return user
    }
    
    func fetchAllUsers() -> [User] {
        let request = User.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \User.displayName, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching users: \(error)")
            return []
        }
    }
    
    // MARK: - Trip Management
    
    @discardableResult
    func createTrip(title: String, description: String?, startDate: Date, owner: User) -> Trip {
        let trip = Trip(context: viewContext)
        trip.id = UUID()
        trip.title = title
        trip.tripDescription = description
        trip.startDate = startDate
        trip.isActive = false
        trip.createdAt = Date()
        trip.owner = owner
        return trip
    }
    
    func fetchTrips(for user: User) -> [Trip] {
        let request = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@ OR ANY participants == %@", user, user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching trips: \(error)")
            return []
        }
    }
    
    func setTripActive(_ trip: Trip, isActive: Bool) {
        trip.isActive = isActive
    }
    
    // MARK: - Memory Management (Footsteps)
    
    @discardableResult
    func createMemory(title: String, content: String?, latitude: Double, longitude: Double, author: User, trip: Trip, photo: UIImage?) -> Memory {
        let memory = Memory(context: viewContext)
        memory.id = UUID()
        memory.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        memory.content = content?.trimmingCharacters(in: .whitespacesAndNewlines)
        memory.latitude = latitude
        memory.longitude = longitude
        memory.timestamp = Date()
        memory.createdAt = Date()
        memory.author = author
        memory.trip = trip
        
        if let image = photo {
            print("📷 CoreDataManager: Erstelle Photo für Memory...")
            let photoEntity = Photo(context: viewContext)
            photoEntity.id = UUID()
            photoEntity.createdAt = Date()
            
            // ✅ KRITISCHER FIX: Konsistente Photo-Directory Verwendung
            let photosDirectory = getPhotosDirectory()
            
            // ✅ KRITISCHER FIX: Setze filename BEVOR saveUIImage aufgerufen wird
            let timestamp = DateFormatter.coreDataFilenameFormatter.string(from: Date())
            let uniqueFilename = "photo_\(timestamp)_\(UUID().uuidString.prefix(8)).jpg"
            photoEntity.filename = uniqueFilename
            
            print("📷 CoreDataManager: Speichere Photo mit Filename: \(uniqueFilename)")
            print("📷 CoreDataManager: Verwende Photos Directory: \(photosDirectory.path)")
            
            if photoEntity.saveUIImage(image, to: photosDirectory) {
                memory.addToPhotos(photoEntity)
                print("✅ CoreDataManager: Foto erfolgreich gespeichert und zur Memory hinzugefügt.")
                print("   - Filename: \(photoEntity.filename ?? "nil")")
                print("   - LocalURL: \(photoEntity.localURL ?? "nil")")
                
                // ✅ ZUSÄTZLICHE Validierung: Prüfe ob File wirklich existiert
                if let localURL = photoEntity.localURL {
                    let fileExists = FileManager.default.fileExists(atPath: localURL)
                    print(fileExists ? "✅ CoreDataManager: Photo-Datei existiert auf Disk" : "❌ CoreDataManager: Photo-Datei existiert NICHT auf Disk!")
                    
                    // ✅ ZUSÄTZLICHER DEBUG: File-Größe und Berechtigungen prüfen
                    if fileExists {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: localURL)
                            let fileSize = attributes[.size] as? Int64 ?? 0
                            print("📷 CoreDataManager: Photo-Datei Größe: \(fileSize) bytes")
                        } catch {
                            print("⚠️ CoreDataManager: Fehler beim Lesen der Datei-Attribute: \(error)")
                        }
                    }
                } else {
                    print("❌ CoreDataManager: LocalURL ist nil!")
                }
                
            } else {
                print("❌ CoreDataManager: Fehler beim Speichern des Fotos.")
                viewContext.delete(photoEntity)
            }
        }
        
        return memory
    }
    
    /// Konsistente Photos Directory Erstellung
    func getPhotosDirectory() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDirectory = documentsDirectory.appendingPathComponent("Photos")
        
        // ✅ WICHTIG: Directory erstellen falls es nicht existiert
        if !FileManager.default.fileExists(atPath: photosDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true, attributes: nil)
                print("✅ CoreDataManager: Photos Directory erstellt: \(photosDirectory.path)")
            } catch {
                print("❌ CoreDataManager: Fehler beim Erstellen des Photos Directory: \(error)")
            }
        }
        
        return photosDirectory
    }
    
    /// Performance-optimierte Memory-Erstellung mit sofortigem Save
    func createMemoryWithImmediateSave(title: String, content: String?, latitude: Double, longitude: Double, author: User, trip: Trip, completion: @escaping (Memory?, Bool) -> Void) {
        
        // KOORDINATEN-VALIDIERUNG vor Context-Operationen
        guard LocationValidator.isValidCoordinate(latitude: latitude, longitude: longitude) else {
            print("❌ CoreDataManager: Ungültige Koordinaten für createMemoryWithImmediateSave")
            completion(nil, false)
            return
        }
        
        // SYNCHRONOUS Erstellung im Main Context für bessere Stabilität
        let memory = createMemory(title: title, content: content, latitude: latitude, longitude: longitude, author: author, trip: trip, photo: nil)
        
        // SOFORTIGER synchroner Save für Konsistenz
        let success = save()
        completion(success ? memory : nil, success)
    }
    
    /// ÜBERARBEITETE Background Memory-Erstellung - PERFORMANCE-OPTIMIERT
    func createMemoryInBackground(title: String, content: String?, latitude: Double, longitude: Double, authorID: UUID, tripID: UUID, completion: @escaping (Bool) -> Void) {
        
        // FRÜHE Koordinaten-Validierung
        guard LocationValidator.isValidCoordinate(latitude: latitude, longitude: longitude) else {
            print("❌ CoreDataManager: Ungültige Koordinaten für Background Memory")
            DispatchQueue.main.async { completion(false) }
            return
        }
        
        // REDUZIERTER TIMEOUT-SCHUTZ für Background Operations (von 5s auf 2s)
        let timeoutWorkItem = DispatchWorkItem {
            print("⚠️ CoreDataManager: Background Memory-Erstellung Timeout nach 2s")
            DispatchQueue.main.async { completion(false) }
        }
        
        // 2 Sekunden Timeout für bessere Responsiveness
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.0, execute: timeoutWorkItem)
        
        // SCHNELLERE Background-Task mit optimierten Fetches
        persistentContainer.performBackgroundTask { context in
            do {
                // OPTIMIERTE Batch-Fetch-Requests mit Limits
                let authorRequest = User.fetchRequest()
                authorRequest.predicate = NSPredicate(format: "id == %@", authorID as CVarArg)
                authorRequest.fetchLimit = 1
                authorRequest.returnsObjectsAsFaults = false // Eager loading
                
                let tripRequest = Trip.fetchRequest()
                tripRequest.predicate = NSPredicate(format: "id == %@", tripID as CVarArg)
                tripRequest.fetchLimit = 1
                tripRequest.returnsObjectsAsFaults = false // Eager loading
                
                // PARALLELE Fetches für bessere Performance
                let fetchGroup = DispatchGroup()
                var author: User?
                var trip: Trip?
                var fetchError: Error?
                
                fetchGroup.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        author = try context.fetch(authorRequest).first
                    } catch {
                        fetchError = error
                    }
                    fetchGroup.leave()
                }
                
                fetchGroup.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        trip = try context.fetch(tripRequest).first
                    } catch {
                        fetchError = error
                    }
                    fetchGroup.leave()
                }
                
                // Warte auf Fetches mit Timeout
                let fetchTimeout = fetchGroup.wait(timeout: .now() + 1.0)
                
                guard fetchTimeout == .success else {
                    timeoutWorkItem.cancel()
                    print("❌ CoreDataManager: Fetch-Timeout bei Background Memory-Erstellung")
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                
                guard let fetchedAuthor = author,
                      let fetchedTrip = trip,
                      fetchError == nil else {
                    timeoutWorkItem.cancel()
                    print("❌ CoreDataManager: Author oder Trip nicht im Background Context gefunden")
                    if let error = fetchError {
                        print("❌ Fetch Error: \(error)")
                    }
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                
                // SCHNELLE Memory-Erstellung ohne weitere Async-Calls
                let memory = Memory(context: context)
                memory.id = UUID()
                memory.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                memory.content = content?.trimmingCharacters(in: .whitespacesAndNewlines)
                memory.latitude = latitude
                memory.longitude = longitude
                memory.timestamp = Date()
                memory.createdAt = Date()
                memory.author = fetchedAuthor
                memory.trip = fetchedTrip
                
                // SCHNELLER synchroner Save im Background Context
                try context.save()
                
                timeoutWorkItem.cancel()
                print("✅ CoreDataManager: Memory erfolgreich im Background erstellt")
                DispatchQueue.main.async { completion(true) }
                
            } catch {
                timeoutWorkItem.cancel()
                print("❌ CoreDataManager: Background Memory-Erstellung fehlgeschlagen: \(error)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    // Alias methods for consistency with Footstep naming
    @discardableResult
    func createFootstep(title: String, content: String?, latitude: Double, longitude: Double, author: User, trip: Trip) -> Memory {
        return createMemory(title: title, content: content, latitude: latitude, longitude: longitude, author: author, trip: trip, photo: nil)
    }
    
    func fetchFootsteps(for trip: Trip) -> [Memory] {
        return fetchMemories(for: trip)
    }
    
    func fetchFootsteps(for user: User) -> [Memory] {
        return fetchMemories(for: user)
    }
    
    func fetchFootsteps(for user: User, from startDate: Date, to endDate: Date) -> [Memory] {
        let request = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "author == %@ AND timestamp >= %@ AND timestamp <= %@", user, startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching footsteps for date range: \(error)")
            return []
        }
    }
    
    func fetchFootsteps(near latitude: Double, longitude: Double, radius: Double) -> [Memory] {
        // Vereinfachte Implementierung ohne Core Location Framework
        // In Production würde hier eine geografische Suche implementiert
        let request = Memory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            let allMemories = try viewContext.fetch(request)
            return allMemories.filter { memory in
                let distance = distanceBetween(
                    lat1: latitude, lon1: longitude,
                    lat2: memory.latitude, lon2: memory.longitude
                )
                return distance <= radius
            }
        } catch {
            print("❌ CoreDataManager: Error fetching nearby footsteps: \(error)")
            return []
        }
    }
    
    // MARK: - Photo Management
    
    @discardableResult
    func createPhoto(filename: String, localURL: String?, memory: Memory) -> Photo {
        let photo = Photo(context: viewContext)
        photo.id = UUID()
        photo.filename = filename
        photo.localURL = localURL
        photo.createdAt = Date()
        photo.memory = memory
        return photo
    }
    
    // Overloaded method for Footstep compatibility
    @discardableResult
    func createPhoto(filename: String, localURL: String?, footstep: Memory) -> Photo {
        return createPhoto(filename: filename, localURL: localURL, memory: footstep)
    }
    
    // MARK: - Fetch Helpers
    
    func fetchActiveTrip(for user: User) -> Trip? {
        let request = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@ AND isActive == YES", user)
        request.fetchLimit = 1
        
        do {
            return try viewContext.fetch(request).first
        } catch {
            print("❌ CoreDataManager: Error fetching active trip: \(error)")
            return nil
        }
    }
    
    func fetchAllTrips() -> [Trip] {
        let request = Trip.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching trips: \(error)")
            return []
        }
    }
    
    func fetchMemories(for trip: Trip) -> [Memory] {
        let request = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "trip == %@", trip)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching memories: \(error)")
            return []
        }
    }
    
    func fetchMemories(for user: User) -> [Memory] {
        let request = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "author == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching memories for user: \(error)")
            return []
        }
    }
    
    // MARK: - Data Management
    
    func deleteObject(_ object: NSManagedObject) {
        viewContext.delete(object)
    }
    
    func clearAllData() {
        let entities = ["Photo", "Memory", "Trip", "User"]
        
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try viewContext.execute(deleteRequest)
                print("✅ CoreDataManager: \(entityName) data cleared")
            } catch {
                print("❌ CoreDataManager: Error clearing \(entityName): \(error)")
            }
        }
        
        save()
    }
    
    // MARK: - Helper Methods
    
    private func distanceBetween(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        // Haversine formula for distance calculation
        let earthRadius: Double = 6371000 // meters
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return earthRadius * c
    }
    
    // MARK: - Object Validation
    
    /// Validiert ob ein NSManagedObject noch gültig und verwendbar ist
    func isValidObject(_ object: NSManagedObject) -> Bool {
        // Basis-Validierungen
        guard !object.isDeleted,
              !object.isFault,
              let context = object.managedObjectContext else {
            return false
        }
        
        // Context-Validierung
        guard !context.concurrencyType.hashValue.isMultiple(of: 0) else {
            return false
        }
        
        // ObjectID-Validierung
        let objectID = object.objectID
        guard !objectID.isTemporaryID || context.insertedObjects.contains(object) else {
            return false
        }
        
        return true
    }
    
    /// Stellt sicher, dass ein Object im angegebenen Context verfügbar ist
    func ensureObjectInContext<T: NSManagedObject>(_ object: T, context: NSManagedObjectContext) -> T? {
        // Bereits im richtigen Context
        if object.managedObjectContext == context {
            return object
        }
        
        // Versuche Object im Ziel-Context zu finden
        do {
            return try context.existingObject(with: object.objectID) as? T
        } catch {
            print("❌ CoreDataManager: Fehler beim Context-Transfer: \(error)")
            return nil
        }
    }
    
    // MARK: - Performance-optimierte Batch Operations
    
    /// Batch Memory-Erstellung für bessere Performance bei mehreren Memories
    func createMemoriesBatch(_ memoryData: [(title: String, content: String?, latitude: Double, longitude: Double)], author: User, trip: Trip, completion: @escaping (Bool, Int) -> Void) {
        performBackgroundTask { context in
            // Hole Author und Trip im Background Context
            guard let backgroundAuthor = context.object(with: author.objectID) as? User,
                  let backgroundTrip = context.object(with: trip.objectID) as? Trip else {
                DispatchQueue.main.async { completion(false, 0) }
                return
            }
            
            var createdCount = 0
            
            // Batch-Erstellung aller Memories
            for data in memoryData {
                let memory = Memory(context: context)
                memory.id = UUID()
                memory.title = data.title.trimmingCharacters(in: .whitespacesAndNewlines)
                memory.content = data.content?.trimmingCharacters(in: .whitespacesAndNewlines)
                memory.latitude = data.latitude
                memory.longitude = data.longitude
                memory.timestamp = Date()
                memory.createdAt = Date()
                memory.author = backgroundAuthor
                memory.trip = backgroundTrip
                createdCount += 1
            }
            
            // Ein einziger Save für alle Memories
            do {
                try context.save()
                print("✅ CoreDataManager: \(createdCount) Memories in Batch erstellt")
                DispatchQueue.main.async { completion(true, createdCount) }
            } catch {
                print("❌ CoreDataManager: Batch Memory creation failed: \(error)")
                DispatchQueue.main.async { completion(false, 0) }
            }
        }
    }
    
    /// Performance-optimierte Memory-Fetch mit Paging
    func fetchMemories(for trip: Trip, limit: Int = 50, offset: Int = 0) -> [Memory] {
        let request = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "trip == %@", trip)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        request.fetchLimit = limit
        request.fetchOffset = offset
        request.returnsObjectsAsFaults = false // Eager loading für bessere Performance
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching memories with paging: \(error)")
            return []
        }
    }
    
    /// NEUE Performance-optimierte Async Memory-Fetch für bessere UI-Performance
    func fetchMemoriesAsync(for trip: Trip, completion: @escaping ([Memory]) -> Void) {
        let tripObjectID = trip.objectID
        
        // REDUZIERTER TIMEOUT-SCHUTZ für Async-Operationen (von 3s auf 1.5s)
        let timeoutWorkItem = DispatchWorkItem {
            print("⚠️ CoreDataManager: Memory-Fetch Timeout nach 1.5s")
            DispatchQueue.main.async { completion([]) }
        }
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5, execute: timeoutWorkItem)
        
        // FIXED: Verwende Core Data's performBackgroundTask für Concurrency-Safety
        persistentContainer.performBackgroundTask { backgroundContext in
            do {
                // DIREKTE Memory-Suche mit Trip ObjectID statt Trip-Objekt-Suche
                let request = Memory.fetchRequest()
                request.predicate = NSPredicate(format: "trip.objectID == %@", tripObjectID)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
                request.returnsObjectsAsFaults = false // Eager loading
                request.fetchLimit = 50 // Limit für Performance
                request.fetchBatchSize = 20 // Batch-Processing
                
                let memories = try backgroundContext.fetch(request)
                
                timeoutWorkItem.cancel()
                print("✅ CoreDataManager: \(memories.count) Memories async geladen")
                DispatchQueue.main.async { completion(memories) }
                
            } catch {
                timeoutWorkItem.cancel()
                print("❌ CoreDataManager: Error in async memory fetch: \(error)")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }
    
    // MARK: - Data Validation and Cleanup
    
    /// NEUE Validierung und Bereinigung aller Memory-Koordinaten - PERFORMANCE-OPTIMIERT
    func validateAndFixMemoryCoordinates() {
        print("🔍 CoreDataManager: Starte Performance-optimierte Koordinaten-Validierung...")
        
        // BACKGROUND-Validierung um UI nicht zu blockieren
        persistentContainer.performBackgroundTask { context in
            let request = Memory.fetchRequest()
            request.returnsObjectsAsFaults = false
            request.fetchBatchSize = 50 // Batch-Processing für bessere Performance
            
            do {
                let allMemories = try context.fetch(request)
                var fixedCount = 0
                var invalidCount = 0
                var batchChanges = false
                
                for memory in allMemories {
                    let wasInvalid = !LocationValidator.isValidCoordinate(latitude: memory.latitude, longitude: memory.longitude)
                    
                    if wasInvalid {
                        invalidCount += 1
                        
                        // Bereinige ungültige Koordinaten
                        let sanitized = LocationValidator.sanitizeCoordinates(latitude: memory.latitude, longitude: memory.longitude)
                        
                        print("🔧 CoreDataManager: Bereinige Memory '\(memory.title ?? "Unknown")': \(memory.latitude),\(memory.longitude) → \(sanitized.lat),\(sanitized.lon)")
                        
                        memory.latitude = sanitized.lat
                        memory.longitude = sanitized.lon
                        fixedCount += 1
                        batchChanges = true
                    }
                    
                    // BATCH-Save alle 20 Änderungen für bessere Performance
                    if batchChanges && fixedCount % 20 == 0 {
                        try context.save()
                        print("✅ CoreDataManager: Batch-Save nach \(fixedCount) Korrekturen")
                        batchChanges = false
                    }
                }
                
                // FINAL Save für verbleibende Änderungen
                if batchChanges {
                    try context.save()
                }
                
                // ERFOLGS-Log im Main Thread
                DispatchQueue.main.async {
                    if fixedCount > 0 {
                        print("✅ CoreDataManager: \(fixedCount) von \(invalidCount) ungültigen Koordinaten bereinigt")
                    } else {
                        print("✅ CoreDataManager: Alle \(allMemories.count) Memory-Koordinaten sind gültig")
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    print("❌ CoreDataManager: Fehler bei Koordinaten-Validierung: \(error)")
                }
            }
        }
    }
    
    /// Prüft die Datenbankintegrität und gibt einen Bericht aus
    func validateDatabaseIntegrity() {
        print("\n📊 CoreDataManager: Datenbankintegritäts-Prüfung")
        print(String(repeating: "=", count: 50))
        
        // Users
        let users = fetchAllUsers()
        print("👤 Users: \(users.count)")
        for user in users {
            let userTrips = fetchTrips(for: user)
            let userMemories = fetchMemories(for: user)
            
            // Erweiterte User-Validierung
            let isUserValid = isValidObject(user)
            let userStatus = isUserValid ? "✅" : "❌"
            
            print("   \(userStatus) \(user.displayName ?? "Unknown"): \(userTrips.count) Trips, \(userMemories.count) Memories")
            
            if !isUserValid {
                print("      ⚠️ User-Object ist ungültig: deleted=\(user.isDeleted), context=\(user.managedObjectContext != nil)")
            }
        }
        
        // Trips
        let trips = fetchAllTrips()
        print("🧳 Trips: \(trips.count)")
        var activeTripsCount = 0
        var invalidTripsCount = 0
        
        for trip in trips {
            if trip.isActive { activeTripsCount += 1 }
            
            let tripMemories = fetchMemories(for: trip)
            let isTripValid = isValidObject(trip)
            let tripStatus = isTripValid ? "✅" : "❌"
            
            if !isTripValid { invalidTripsCount += 1 }
            
            print("   \(tripStatus) \(trip.title ?? "Unknown"): \(tripMemories.count) Memories\(trip.isActive ? " (AKTIV)" : "")")
            
            if !isTripValid {
                print("      ⚠️ Trip-Object ist ungültig: deleted=\(trip.isDeleted), context=\(trip.managedObjectContext != nil)")
            }
        }
        
        if activeTripsCount > 1 {
            print("⚠️ Warnung: \(activeTripsCount) aktive Trips gefunden (sollte max. 1 sein)")
        }
        
        if invalidTripsCount > 0 {
            print("⚠️ Warnung: \(invalidTripsCount) ungültige Trip-Objekte gefunden")
        }
        
        // Memories mit ungültigen Koordinaten
        let request = Memory.fetchRequest()
        request.fetchBatchSize = 50 // Batch für Performance
        
        do {
            let allMemories = try viewContext.fetch(request)
            var invalidCoordinatesCount = 0
            var invalidMemoriesCount = 0
            var orphanMemoriesCount = 0
            
            for memory in allMemories {
                // Koordinaten-Validierung
                if !LocationValidator.isValidCoordinate(latitude: memory.latitude, longitude: memory.longitude) {
                    invalidCoordinatesCount += 1
                }
                
                // Memory-Object-Validierung
                if !isValidObject(memory) {
                    invalidMemoriesCount += 1
                }
                
                // Relationship-Validierung
                if memory.author == nil || memory.trip == nil {
                    orphanMemoriesCount += 1
                }
            }
            
            print("📍 Memories: \(allMemories.count) total")
            
            if invalidCoordinatesCount > 0 {
                print("⚠️ Ungültige Koordinaten: \(invalidCoordinatesCount)")
            } else {
                print("✅ Alle Koordinaten sind gültig")
            }
            
            if invalidMemoriesCount > 0 {
                print("⚠️ Ungültige Memory-Objekte: \(invalidMemoriesCount)")
            }
            
            if orphanMemoriesCount > 0 {
                print("⚠️ Memories ohne Author/Trip: \(orphanMemoriesCount)")
            }
            
            if invalidCoordinatesCount == 0 && invalidMemoriesCount == 0 && orphanMemoriesCount == 0 {
                print("✅ Alle Memories sind gültig und korrekt verknüpft")
            }
            
        } catch {
            print("❌ Fehler bei Memory-Prüfung: \(error)")
        }
        
        // Context-Status
        print("📋 Context-Status:")
        print("   - Has Changes: \(viewContext.hasChanges)")
        print("   - Inserted Objects: \(viewContext.insertedObjects.count)")
        print("   - Updated Objects: \(viewContext.updatedObjects.count)")
        print("   - Deleted Objects: \(viewContext.deletedObjects.count)")
        
        print(String(repeating: "=", count: 50))
        print("")
    }
    
    /// NEUE FUNKTION: Automatische Problem-Behebung
    func fixDatabaseIssues() {
        print("🔧 CoreDataManager: Starte automatische Problem-Behebung...")
        
        var fixedIssues = 0
        
        // 1. Koordinaten-Bereinigung
        print("🔍 Prüfe Memory-Koordinaten...")
        validateAndFixMemoryCoordinates()
        
        // 2. Orphan Memories bereinigen
        print("🔍 Prüfe verwaiste Memories...")
        let memoryRequest = Memory.fetchRequest()
        do {
            let allMemories = try viewContext.fetch(memoryRequest)
            for memory in allMemories {
                if memory.author == nil || memory.trip == nil {
                    print("🗑️ Lösche verwaistes Memory: \(memory.title ?? "Unknown")")
                    viewContext.delete(memory)
                    fixedIssues += 1
                }
            }
        } catch {
            print("❌ Fehler bei Orphan-Memory-Prüfung: \(error)")
        }
        
        // 3. Doppelte aktive Trips beheben
        print("🔍 Prüfe aktive Trips...")
        let activeTripsRequest = Trip.fetchRequest()
        activeTripsRequest.predicate = NSPredicate(format: "isActive == true")
        do {
            let activeTrips = try viewContext.fetch(activeTripsRequest)
            if activeTrips.count > 1 {
                print("🔧 Bereinige \(activeTrips.count - 1) doppelte aktive Trips...")
                // Behalte nur den neuesten Trip aktiv
                let sortedTrips = activeTrips.sorted { ($0.startDate ?? Date.distantPast) > ($1.startDate ?? Date.distantPast) }
                for (index, trip) in sortedTrips.enumerated() {
                    if index > 0 { // Alle außer dem ersten (neuesten) deaktivieren
                        trip.isActive = false
                        fixedIssues += 1
                    }
                }
            }
        } catch {
            print("❌ Fehler bei aktive-Trips-Prüfung: \(error)")
        }
        
        // 4. Ungültige Objects entfernen
        print("🔍 Prüfe ungültige Objects...")
        for object in viewContext.registeredObjects {
            if object.isDeleted && viewContext.insertedObjects.contains(object) {
                print("🗑️ Entferne ungültiges inserted Object: \(object)")
                viewContext.delete(object)
                fixedIssues += 1
            }
        }
        
        // Änderungen speichern falls welche vorhanden
        if fixedIssues > 0 {
            print("💾 Speichere \(fixedIssues) Korrekturen...")
            if save() {
                print("✅ Problem-Behebung abgeschlossen: \(fixedIssues) Issues behoben")
            } else {
                print("❌ Fehler beim Speichern der Korrekturen")
            }
        } else {
            print("✅ Keine Probleme gefunden - Datenbank ist in Ordnung")
        }
    }
}

// MARK: - DateFormatter Extension for CoreDataManager
private extension DateFormatter {
    static let coreDataFilenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
} 