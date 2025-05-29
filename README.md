# TravelCompanion - Core Data Model

Eine iOS Reise-App mit robustem Core Data Foundation und intelligenten GPS-Tracking für das MVP.

## 🏗️ Architektur

### Core Data Stack
- **CoreDataManager**: Zentrale Verwaltung des Core Data Stacks
- **PersistenceController**: SwiftUI-kompatible Persistence-Lösung
- **Entity Extensions**: Erweiterte Funktionalität für alle Entities

### 📍 GPS-Tracking System
- **LocationManager**: Intelligentes GPS-Tracking mit Batterie-Optimierung
- **Automatische Pause-Erkennung**: Energiesparmodus bei >5 Min Stillstand
- **Offline-Funktionalität**: Lokale Speicherung ohne Internetverbindung
- **Background-Updates**: Kontinuierliches Tracking im Hintergrund

### 📊 Datenmodell

#### User Entity
```swift
- id: UUID (Primary Key)
- email: String
- displayName: String
- avatarURL: String? (optional)
- createdAt: Date
- isActive: Bool

// Relationships
- ownedTrips: [Trip] (One-to-Many)
- participatedTrips: [Trip] (Many-to-Many)
- footsteps: [Footstep] (One-to-Many)
```

#### Trip Entity  
```swift
- id: UUID (Primary Key)
- title: String
- tripDescription: String? (optional)
- startDate: Date
- endDate: Date? (optional)
- isActive: Bool
- createdAt: Date

// Relationships
- owner: User (Many-to-One)
- participants: [User] (Many-to-Many)
- footsteps: [Footstep] (One-to-Many)
```

#### Footstep Entity
```swift
- id: UUID (Primary Key)
- title: String
- content: String? (optional)
- latitude: Double
- longitude: Double
- timestamp: Date
- createdAt: Date

// Relationships
- author: User (Many-to-One)
- trip: Trip (Many-to-One)
- photos: [Photo] (One-to-Many)
```

#### Photo Entity
```swift
- id: UUID (Primary Key)
- filename: String
- localURL: String? (für offline)
- cloudURL: String? (für sync)
- createdAt: Date

// Relationships
- footstep: Footstep (Many-to-One)
```

## 🚀 Verwendung

### 1. Core Data Manager initialisieren
```swift
let coreDataManager = CoreDataManager.shared
```

### 2. User erstellen
```swift
let user = coreDataManager.createUser(
    email: "user@example.com",
    displayName: "Max Mustermann"
)
coreDataManager.save()
```

### 3. Trip erstellen
```swift
let trip = coreDataManager.createTrip(
    title: "Italien Reise",
    description: "Schöne Reise durch die Toskana",
    startDate: Date(),
    owner: user
)
coreDataManager.save()
```

### 4. Footstep hinzufügen
```swift
let footstep = coreDataManager.createFootstep(
    title: "Kolosseum besucht",
    content: "Beeindruckende Architektur!",
    latitude: 41.8902,
    longitude: 12.4922,
    author: user,
    trip: trip
)
coreDataManager.save()
```

### 5. Photo hinzufügen
```swift
let photo = coreDataManager.createPhoto(
    filename: "kolosseum.jpg",
    localURL: "/local/path/kolosseum.jpg",
    footstep: footstep
)
coreDataManager.save()
```

## 🔧 SwiftUI Integration

### App Setup
```swift
import SwiftUI

@main
struct TravelCompanionApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
```

### SwiftUI Previews
```swift
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
```

## 🧪 Testing mit Sample Data

### Sample Data erstellen
```swift
// In deiner App oder einem Test
SampleDataCreator.createSampleData(in: CoreDataManager.shared.viewContext)

// Zusammenfassung ausgeben
SampleDataCreator.printDataSummary(using: CoreDataManager.shared)
```

### Sample Data Inhalt
- **3 Benutzer**: Max Mustermann, Anna Schmidt, Tom Weber
- **3 Trips**: Toskana Abenteuer, Japan Entdeckung, Schwarzwald Wanderung
- **6 Footsteps**: Mit echten Koordinaten und Beschreibungen
- **1 Photo**: Beispiel-Foto am Kolosseum

## 📁 Dateistruktur

```
TravelCompanion/
├── TravelCompanion.xcdatamodeld/          # Core Data Model
├── CoreData/
│   ├── CoreDataManager.swift             # Stack Management
│   ├── PersistenceController.swift       # SwiftUI Support
│   ├── SampleDataCreator.swift           # Test Data
│   ├── LocationManager.swift             # GPS-Tracking Service
│   └── Models/
│       ├── User+CoreDataClass.swift      # User Erweiterungen
│       ├── User+CoreDataProperties.swift # User Properties
│       ├── Trip+CoreDataClass.swift      # Trip Erweiterungen
│       ├── Trip+CoreDataProperties.swift # Trip Properties
│       ├── Footstep+CoreDataClass.swift  # Footstep Erweiterungen
│       ├── Footstep+CoreDataProperties.swift # Footstep Properties
│       ├── Photo+CoreDataClass.swift     # Photo Erweiterungen
│       └── Photo+CoreDataProperties.swift # Photo Properties
├── LocationManagerExample.swift          # Beispiel-Implementation
└── README.md                             # Diese Dokumentation
```

## ✨ Features

### Entity Extensions
- **User**: Computed Properties für Trip-Kategorien, Initialen, Convenience Methods
- **Trip**: Dauer-Berechnungen, Status-Checks, Teilnehmer-Management
- **Footstep**: Location-Features, Entfernungs-Berechnungen, Zeit-Formatting
- **Photo**: File-Management, Image-Loading, Thumbnail-Generation

### LocationManager Features
- ✅ **Singleton Pattern** mit thread-safe Implementation
- ✅ **Background Location Updates** für kontinuierliches Tracking
- ✅ **Intelligente Batterie-Optimierung** basierend auf Ladestand
- ✅ **Automatische Pause-Erkennung** bei >5 Min Stillstand
- ✅ **Offline-Funktionalität** mit lokaler Speicherung
- ✅ **Core Data Integration** mit Background Contexts
- ✅ **Permission Handling** für alle iOS-Versionen
- ✅ **Error Handling** mit detailliertem Logging

### Core Data Best Practices
- ✅ UUID Primary Keys für alle Entities
- ✅ Proper Delete Rules (Cascade/Nullify)
- ✅ Background Context für schwere Operationen
- ✅ Merge Policies für Konflikt-Resolution
- ✅ Error Handling bei allen Operationen

### Performance Optimizations
- ✅ Lazy Loading von Relationships
- ✅ Efficient Fetch Requests mit Predicates
- ✅ Sort Descriptors für konsistente Sortierung
- ✅ Computed Properties statt wiederholte Fetches
- ✅ Adaptive GPS-Genauigkeit für Batterie-Schonung

## 🔄 Nächste Schritte

Das Core Data Model UND GPS-Tracking System sind vollständig implementiert und ready für:

1. **SwiftUI Views**: Trip-Listen, Footstep-Details, User-Profile, Live-Karte
2. **Map Integration**: MapKit Views für Footstep-Visualisierung
3. **Photo Management**: Camera-Integration, File-Upload für Footsteps
4. **Push Notifications**: Trip-Start/Stop, Milestone-Benachrichtigungen
5. **Sync Layer**: CloudKit oder REST API Integration
6. **Analytics**: Trip-Statistiken, Tracking-Insights

## 🛠️ iOS Setup Requirements

### Info.plist Einträge
```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>TravelCompanion benötigt Standortzugriff für GPS-Tracking Ihrer Reisen.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>TravelCompanion verwendet Ihren Standort für die Reise-Dokumentation.</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

### Capabilities aktivieren
- **Background Modes**: Location updates
- **Location Services**: Always authorization

## 🐛 Debugging

### Core Data Logs aktivieren
```swift
// In AppDelegate oder SceneDelegate
CoreDataManager.shared.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
```

### LocationManager Debug Output
```swift
// Detailliertes Logging ist bereits integriert
// Console zeigt alle wichtigen Events mit Emojis
```

### SQL Debug Output
Add launch argument: `-com.apple.CoreData.SQLDebug 1`

Das komplette GPS-Tracking System ist production-ready! 🚀📍

## 📍 GPS-Tracking mit LocationManager

### LocationManager initialisieren und konfigurieren
```swift
let locationManager = LocationManager.shared

// Berechtigung anfordern
locationManager.requestPermission()

// Tracking-Genauigkeit einstellen
locationManager.setTrackingAccuracy(.balanced) // .low, .balanced, .high, .navigation
```

### GPS-Tracking starten
```swift
// Benutzer und Trip vorbereiten
let user = coreDataManager.createUser(email: "user@example.com", displayName: "Max")
let trip = coreDataManager.createTrip(title: "Italien Reise", startDate: Date(), owner: user)

// Trip als aktiv markieren
coreDataManager.setTripActive(trip, isActive: true)

// Tracking starten
locationManager.startTracking(for: trip, user: user)
```

### Manuelle Footsteps erstellen
```swift
// Aktueller Standort
locationManager.createManualFootstep(
    title: "Kolosseum",
    content: "Beeindruckende römische Architektur!"
)

// Spezifischer Standort
let customLocation = CLLocation(latitude: 41.8902, longitude: 12.4922)
locationManager.createManualFootstep(
    title: "Kolosseum",
    content: "Beeindruckende römische Architektur!",
    location: customLocation
)
```

### Tracking-Status überwachen
```swift
// ObservableObject in SwiftUI
struct TrackingView: View {
    @StateObject private var locationManager = LocationManager.shared
    
    var body: some View {
        VStack {
            // GPS-Status
            HStack {
                Circle()
                    .fill(locationManager.isTracking ? .green : .red)
                    .frame(width: 12, height: 12)
                Text(locationManager.isTracking ? "Tracking aktiv" : "Gestoppt")
            }
            
            // Pause-Status
            if locationManager.isPaused {
                Label("Pausiert - keine Bewegung", systemImage: "pause.circle")
                    .foregroundColor(.orange)
            }
            
            // Aktuelle Position
            if let location = locationManager.currentLocation {
                Text("Lat: \(location.coordinate.latitude, specifier: "%.6f")")
                Text("Lon: \(location.coordinate.longitude, specifier: "%.6f")")
            }
        }
    }
}
```

### LocationManager Features

#### 🔋 Intelligente Batterie-Optimierung
- **Automatische Anpassung**: Reduzierte Genauigkeit bei niedrigem Batteriestand
- **Ladestatus-Erkennung**: Höhere Genauigkeit während des Ladens
- **Adaptive Distanzfilter**: Dynamische Anpassung basierend auf Batterielevel

#### ⏸️ Automatische Pause-Erkennung
- **5-Minuten-Regel**: Automatische Pause bei 5+ Minuten Stillstand
- **Energiesparmodus**: Wechsel zu "Significant Location Changes"
- **Automatische Fortsetzung**: Tracking wird bei Bewegung fortgesetzt

#### 📱 Offline-Funktionalität
- **Lokale Speicherung**: Footsteps werden offline in UserDefaults gespeichert
- **Sync-Mechanismus**: Automatische Synchronisation bei Verbindung
- **Robuste Fehlerbehandlung**: Failover bei Core Data Problemen

#### 🎯 Genauigkeitsstufen
```swift
enum LocationAccuracy {
    case low        // ~1km Genauigkeit, minimaler Verbrauch
    case balanced   // ~100m Genauigkeit, ausgewogen
    case high       // ~10m Genauigkeit, höherer Verbrauch
    case navigation // ~5m Genauigkeit, für Navigation
}
```

### Integration mit Core Data

#### Footsteps abrufen
```swift
// Alle Footsteps eines Trips
let footsteps = coreDataManager.fetchFootsteps(for: trip)

// Footsteps in einem Zeitraum
let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
let todayFootsteps = coreDataManager.fetchFootsteps(for: user, from: yesterday, to: Date())

// Footsteps in der Nähe
let nearbyFootsteps = coreDataManager.fetchFootsteps(
    near: 41.8902, 
    longitude: 12.4922, 
    radius: 500 // 500 Meter
)
```

#### Aktiven Trip verwalten
```swift
// Aktiven Trip eines Users finden
if let activeTrip = coreDataManager.fetchActiveTrip(for: user) {
    locationManager.startTracking(for: activeTrip, user: user)
}
``` 