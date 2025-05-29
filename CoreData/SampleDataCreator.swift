import Foundation
import CoreData

class SampleDataCreator {
    
    static func createSampleData(in context: NSManagedObjectContext) {
        // Alle existierenden Daten löschen
        deleteAllData(in: context)
        
        // Sample Users erstellen
        let user1 = createUser1(in: context)
        let user2 = createUser2(in: context)
        let user3 = createUser3(in: context)
        
        // Sample Trips erstellen
        let trip1 = createItalyTrip(owner: user1, in: context)
        let trip2 = createJapanTrip(owner: user2, in: context)
        let trip3 = createGermanyTrip(owner: user1, in: context)
        
        // Participants hinzufügen
        trip1.addToParticipants(user2)
        trip1.addToParticipants(user3)
        
        trip2.addToParticipants(user1)
        
        trip3.addToParticipants(user2)
        
        // Sample Footsteps erstellen
        createFootstepsForItalyTrip(trip: trip1, users: [user1, user2, user3], in: context)
        createFootstepsForJapanTrip(trip: trip2, users: [user1, user2], in: context)
        createFootstepsForGermanyTrip(trip: trip3, users: [user1, user2], in: context)
        
        // Context speichern
        do {
            try context.save()
            print("✅ Sample Data erfolgreich erstellt!")
        } catch {
            print("❌ Fehler beim Speichern der Sample Data: \(error)")
        }
    }
    
    // MARK: - User Creation
    
    private static func createUser1(in context: NSManagedObjectContext) -> User {
        let user = User(context: context)
        user.id = UUID()
        user.email = "max.mustermann@example.com"
        user.displayName = "Max Mustermann"
        user.avatarURL = "https://example.com/avatars/max.jpg"
        user.createdAt = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        user.isActive = true
        return user
    }
    
    private static func createUser2(in context: NSManagedObjectContext) -> User {
        let user = User(context: context)
        user.id = UUID()
        user.email = "anna.schmidt@example.com"
        user.displayName = "Anna Schmidt"
        user.avatarURL = "https://example.com/avatars/anna.jpg"
        user.createdAt = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
        user.isActive = true
        return user
    }
    
    private static func createUser3(in context: NSManagedObjectContext) -> User {
        let user = User(context: context)
        user.id = UUID()
        user.email = "tom.weber@example.com"
        user.displayName = "Tom Weber"
        user.createdAt = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        user.isActive = true
        return user
    }
    
    // MARK: - Trip Creation
    
    private static func createItalyTrip(owner: User, in context: NSManagedObjectContext) -> Trip {
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.title = "Toskana Abenteuer"
        trip.tripDescription = "Eine wunderschöne Reise durch die Toskana mit Weinverkostungen und historischen Städten"
        trip.startDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        trip.endDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        trip.isActive = false
        trip.createdAt = Calendar.current.date(byAdding: .day, value: -20, to: Date()) ?? Date()
        trip.owner = owner
        return trip
    }
    
    private static func createJapanTrip(owner: User, in context: NSManagedObjectContext) -> Trip {
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.title = "Japan Entdeckung"
        trip.tripDescription = "Kulturelle Reise durch Tokyo, Kyoto und Osaka"
        trip.startDate = Date()
        trip.endDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())
        trip.isActive = true
        trip.createdAt = Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()
        trip.owner = owner
        return trip
    }
    
    private static func createGermanyTrip(owner: User, in context: NSManagedObjectContext) -> Trip {
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.title = "Schwarzwald Wanderung"
        trip.tripDescription = "Entspannende Wanderung durch den Schwarzwald"
        trip.startDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        trip.isActive = false
        trip.createdAt = Date()
        trip.owner = owner
        return trip
    }
    
    // MARK: - Footstep Creation
    
    private static func createFootstepsForItalyTrip(trip: Trip, users: [User], in context: NSManagedObjectContext) {
        // Footstep 1: Rom - Kolosseum
        let footstep1 = Footstep(context: context)
        footstep1.id = UUID()
        footstep1.title = "Kolosseum besucht"
        footstep1.content = "Beeindruckende antike Architektur! Die Geschichte des römischen Reiches ist hier greifbar."
        footstep1.latitude = 41.8902
        footstep1.longitude = 12.4922
        footstep1.timestamp = Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date()
        footstep1.createdAt = Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date()
        footstep1.author = users[0]
        footstep1.trip = trip
        
        // Photo für Kolosseum
        let photo1 = Photo(context: context)
        photo1.id = UUID()
        photo1.filename = "kolosseum_außen.jpg"
        photo1.localURL = "/documents/photos/kolosseum_außen.jpg"
        photo1.cloudURL = "https://cloud.example.com/photos/kolosseum_außen.jpg"
        photo1.createdAt = footstep1.createdAt
        photo1.footstep = footstep1
        
        // Footstep 2: Florenz - Dom
        let footstep2 = Footstep(context: context)
        footstep2.id = UUID()
        footstep2.title = "Dom von Florenz"
        footstep2.content = "Die Kuppel von Brunelleschi ist architektonisch revolutionär. Der Aufstieg war anstrengend aber lohnenswert!"
        footstep2.latitude = 43.7731
        footstep2.longitude = 11.2560
        footstep2.timestamp = Calendar.current.date(byAdding: .day, value: -11, to: Date()) ?? Date()
        footstep2.createdAt = Calendar.current.date(byAdding: .day, value: -11, to: Date()) ?? Date()
        footstep2.author = users[1]
        footstep2.trip = trip
        
        // Footstep 3: Siena - Piazza del Campo
        let footstep3 = Footstep(context: context)
        footstep3.id = UUID()
        footstep3.title = "Piazza del Campo"
        footstep3.content = "Mittelalterliche Atmosphäre pur. Hier findet das berühmte Palio-Pferderennen statt."
        footstep3.latitude = 43.3188
        footstep3.longitude = 11.3307
        footstep3.timestamp = Calendar.current.date(byAdding: .day, value: -9, to: Date()) ?? Date()
        footstep3.createdAt = Calendar.current.date(byAdding: .day, value: -9, to: Date()) ?? Date()
        footstep3.author = users[2]
        footstep3.trip = trip
    }
    
    private static func createFootstepsForJapanTrip(trip: Trip, users: [User], in context: NSManagedObjectContext) {
        // Footstep 1: Tokyo - Senso-ji Tempel
        let footstep1 = Footstep(context: context)
        footstep1.id = UUID()
        footstep1.title = "Senso-ji Tempel"
        footstep1.content = "Ältester Tempel in Tokyo. Die traditionelle Architektur ist wunderschön."
        footstep1.latitude = 35.7148
        footstep1.longitude = 139.7967
        footstep1.timestamp = Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date()
        footstep1.createdAt = Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date()
        footstep1.author = users[0]
        footstep1.trip = trip
        
        // Footstep 2: Tokyo - Shibuya Crossing
        let footstep2 = Footstep(context: context)
        footstep2.id = UUID()
        footstep2.title = "Shibuya Crossing"
        footstep2.content = "Die berühmteste Kreuzung der Welt! Unglaublich viele Menschen überqueren gleichzeitig die Straße."
        footstep2.latitude = 35.6598
        footstep2.longitude = 139.7006
        footstep2.timestamp = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        footstep2.createdAt = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        footstep2.author = users[1]
        footstep2.trip = trip
    }
    
    private static func createFootstepsForGermanyTrip(trip: Trip, users: [User], in context: NSManagedObjectContext) {
        // Footstep 1: Schwarzwald - Titisee
        let footstep1 = Footstep(context: context)
        footstep1.id = UUID()
        footstep1.title = "Titisee Wanderung geplant"
        footstep1.content = "Route um den See geplant. Soll etwa 3 Stunden dauern mit schönen Aussichtspunkten."
        footstep1.latitude = 47.9063
        footstep1.longitude = 8.1453
        footstep1.timestamp = Date()
        footstep1.createdAt = Date()
        footstep1.author = users[0]
        footstep1.trip = trip
    }
    
    // MARK: - Cleanup
    
    private static func deleteAllData(in context: NSManagedObjectContext) {
        let entities = ["User", "Trip", "Footstep", "Photo"]
        
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("Fehler beim Löschen von \(entityName): \(error)")
            }
        }
    }
    
    // MARK: - Test Helper Methods
    
    static func printDataSummary(using manager: CoreDataManager) {
        let users = manager.fetchUsers()
        let activeTrips = manager.fetchActiveTrips()
        
        print("\n📊 DATENBANK ZUSAMMENFASSUNG:")
        print("👥 Users: \(users.count)")
        print("🗺️ Aktive Trips: \(activeTrips.count)")
        
        for user in users {
            print("\n👤 \(user.displayName)")
            print("   📧 \(user.email)")
            print("   🗂️ Trips gesamt: \(user.allTrips.count)")
            print("   📍 Footsteps: \(user.totalFootsteps)")
        }
        
        print("\n🗺️ AKTIVE TRIPS:")
        for trip in activeTrips {
            print("   \(trip.title) - \(trip.participantCount) Teilnehmer")
        }
    }
} 