# TravelCompanion - Core Data Model

Eine iOS Reise-App mit robustem Core Data Foundation und intelligenten GPS-Tracking für das MVP.

## 🚀 **RECENT FIXES** ✅ 

### Problem behoben: Kamera-Crash
- ✅ **NSCameraUsageDescription** hinzugefügt - Kamera-Berechtigung 
- ✅ **NSPhotoLibraryUsageDescription** hinzugefügt - Foto-Bibliothek-Berechtigung
- ✅ **Verbesserte Fehlerbehandlung** mit Weiterleitung zu iOS-Einstellungen
- ✅ **Production-ready PhotoPicker** mit Settings-Integration

### Problem behoben: LocationManager Authorization
- ✅ **NSLocationAlwaysAndWhenInUseUsageDescription** hinzugefügt
- ✅ **NSLocationWhenInUseUsageDescription** hinzugefügt  
- ✅ **NSLocationAlwaysUsageDescription** hinzugefügt
- ✅ **LocationManager beim App-Start initialisiert** mit automatischer Berechtigung-Anforderung
- ✅ **Verbesserte Alert-Funktionalität** für Einstellungen-Weiterleitung

## 🏗️ Architektur

### Core Data Stack
- **CoreDataManager**: Zentrale Verwaltung des Core Data Stacks
- **PersistenceController**: SwiftUI-kompatible Persistence-Lösung
- **Entity Extensions**: Erweiterte Funktionalität für alle Entities

### 📍 GPS-Tracking System ✅ VOLLSTÄNDIG IMPLEMENTIERT
- **LocationManager**: Intelligentes GPS-Tracking mit Batterie-Optimierung
- **Automatische Pause-Erkennung**: Energiesparmodus bei >5 Min Stillstand
- **Offline-Funktionalität**: Lokale Speicherung ohne Internetverbindung
- **Background-Updates**: Kontinuierliches Tracking im Hintergrund
- **Test-Tools**: Vollständiges Test-Framework für Simulator und Device

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
TravelCompanion/                              # Xcode Workspace Root
├── TravelCompanion/                          # Haupt-Xcode-Project-Verzeichnis  
│   ├── TravelCompanion.xcodeproj/           # Xcode Project
│   ├── TravelCompanionTests/                # Unit Tests  
│   ├── TravelCompanionUITests/              # UI Tests
│   └── TravelCompanion/                     # ✅ App Source Code (Alles im App-Target)
│       ├── TravelCompanionApp.swift         # App Entry Point
│       ├── ContentView.swift               # Haupt-View
│       ├── Persistence.swift               # Legacy Core Data Support
│       ├── Info.plist                      # App Konfiguration
│       ├── Assets.xcassets/               # App Assets (Bilder, Icons)
│       │
│       ├── Core/                          # 🏗️ Core Services & Foundation
│       │   ├── CoreData/                  # Core Data Stack
│       │   │   ├── CoreDataManager.swift          # Stack Management
│       │   │   ├── PersistenceController.swift    # SwiftUI Support
│       │   │   ├── SampleDataCreator.swift        # Test Data
│       │   │   ├── TravelCompanion.xcdatamodeld/  # Core Data Model
│       │   │   └── Models/                        # Generated Models
│       │   │       ├── User+CoreDataClass.swift      
│       │   │       ├── User+CoreDataProperties.swift  
│       │   │       ├── Trip+CoreDataClass.swift      
│       │   │       ├── Trip+CoreDataProperties.swift 
│       │   │       ├── Footstep+CoreDataClass.swift  
│       │   │       ├── Footstep+CoreDataProperties.swift
│       │   │       ├── Photo+CoreDataClass.swift     
│       │   │       └── Photo+CoreDataProperties.swift
│       │   │
│       │   ├── Location/                  # 📍 GPS & Location Services
│       │   │   ├── LocationManager.swift          # Intelligentes GPS-Tracking
│       │   │   ├── LocationManagerExample.swift   # Usage Examples
│       │   │   └── GPSTestScript.swift           # Test Framework
│       │   │
│       │   └── Networking/               # 🌐 API & Sync Services
│       │       └── (Future: API Manager, CloudKit Sync)
│       │
│       ├── Features/                     # 📱 App Features (Feature-Based Architecture)
│       │   ├── Memories/                # 📸 Memory Creation & Management  
│       │   │   ├── MemoryCreationView.swift
│       │   │   ├── MemoryCreationViewModel.swift
│       │   │   ├── EnhancedMemoryCreationView.swift
│       │   │   ├── EnhancedMemoryCreationViewModel.swift
│       │   │   ├── MemoryCardView.swift
│       │   │   ├── PhotoPicker.swift
│       │   │   └── MemoryCreationExample.swift
│       │   │
│       │   ├── Timeline/                # 📅 Timeline & Trip History
│       │   │   ├── TimelineView.swift          
│       │   │   ├── TimelineViewModel.swift     
│       │   │   └── EmptyStateView.swift        
│       │   │
│       │   ├── Trips/                   # 🗺️ Trip Management
│       │   │   ├── TripCreationView.swift      
│       │   │   ├── TripsListView.swift          
│       │   │   └── (Future: TripDetailView.swift, TripViewModel.swift)
│       │   │
│       │   └── Profile/                 # 👤 User Profile & Settings
│       │       └── (Future: ProfileView.swift, SettingsView.swift)
│       │
│       ├── Utils/                       # 🛠️ Utilities & Helpers
│       │   ├── Extensions/              # Swift Extensions
│       │   └── Helpers/                 # Helper Classes & Functions
│       │
│       ├── Resources/                   # 📋 App Resources
│       │   └── Info.plist.template      # Template für Permissions Setup
│       │
│       └── Tests/                       # 🧪 Test Infrastructure  
│           ├── Unit/                    # Unit Tests
│           └── Integration/             # Integration Tests
│
├── Documentation/                        # 📚 Project Documentation
│   ├── TRIP_MANAGEMENT_DOCUMENTATION.md
│   ├── TIMELINE_IMPLEMENTATION_DOCUMENTATION.md
│   ├── MEMORY_CREATION_DOCUMENTATION.md
│   └── GPS_IMPLEMENTATION_SUMMARY.md
│
├── README.md                            # Diese Dokumentation
└── .gitignore                          # Git Ignore Rules
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

## 🚀 GPS-Tracking: Production-Ready Implementation

### ✅ **LocationManager Features - Vollständig implementiert**

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

### 🧪 **Neue Test-Tools für Development**

#### GPSTestScript.swift
- **Komplett-Test-Scenario**: Automatisierte Tests aller GPS-Features
- **Quick Tests**: Schnelle Tests für aktuelle Entwicklung
- **Simulator-Integration**: Vordefinierte Test-Locations (Rom, Florenz, Venedig)
- **Test-View**: SwiftUI Interface für interaktive Tests

#### Info.plist.template
- **Vollständige Permissions**: Alle erforderlichen Location-Berechtigungen
- **Background Modes**: Konfiguration für kontinuierliches GPS
- **Setup-Anleitung**: Detaillierte Xcode-Konfiguration
- **App Store Guidelines**: Hinweise für Review-Prozess

## 🔧 Testing & Development

### GPS-Tests im Simulator
```swift
// Quick Test starten
GPSTestScript.shared.quickTest()

// Vollständiges Test-Scenario
Task {
    await GPSTestScript.shared.runCompleteGPSTest()
}

// Test beenden und Ergebnisse anzeigen
GPSTestScript.shared.stopTestAndShowResults()
```

### Test-View in SwiftUI integrieren
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // Ihre App Views
            
            // GPS Test Tab (nur für Development)
            #if DEBUG
            GPSTestView()
                .tabItem {
                    Image(systemName: "location.circle")
                    Text("GPS Test")
                }
            #endif
        }
    }
}
```

### Simulator Location Setup
1. **iOS Simulator** öffnen
2. **Device → Location → Custom Location...**
3. **Test-Koordinaten** eingeben:
   - Rom: `41.8902, 12.4922`
   - Florenz: `43.7731, 11.2560`
   - Venedig: `45.4342, 12.3388`
4. Oder **automatische Simulation**: `Device → Location → City Run`

## 🛠️ iOS Setup Requirements

### Info.plist Einträge
```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>TravelCompanion benötigt Standortzugriff für GPS-Tracking Ihrer Reisen.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>TravelCompanion verwendet Ihren Standort für die Reise-Dokumentation.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>TravelCompanion benötigt Standortzugriff für GPS-Tracking Ihrer Reisen.</string>

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

Das komplette GPS-Tracking System ist **production-ready** und kann sofort verwendet werden! 🚀📍

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

## ✨ Production-Ready Status

### ✅ **Vollständig implementiert:**
- Core Data Model mit allen Entities
- LocationManager mit intelligenter GPS-Funktionalität
- Batterie-Optimierung und Pause-Erkennung
- Offline-Speicherung und Sync-Mechanismen
- Test-Framework für Development
- Info.plist Template mit allen Permissions

### 🚀 **Ready für nächste Schritte:**
1. **SwiftUI Views**: Trip-Listen, Footstep-Details, User-Profile, Live-Karte
2. **Map Integration**: MapKit Views für Footstep-Visualisierung
3. **Photo Management**: Camera-Integration, File-Upload für Footsteps
4. **Push Notifications**: Trip-Start/Stop, Milestone-Benachrichtigungen
5. **Sync Layer**: CloudKit oder REST API Integration
6. **Analytics**: Trip-Statistiken, Tracking-Insights

## 🛠️ Quick Start Guide

### 1. Xcode Project Setup
```bash
# Info.plist konfigurieren
cp Info.plist.template YourApp/Info.plist

# Capabilities aktivieren in Xcode:
# - Background Modes > Location updates
# - Location Services permissions
```

### 2. GPS-Tracking initialisieren
```swift
// In AppDelegate oder SceneDelegate
LocationManager.shared.requestPermission()

// Sample Data für Tests
SampleDataCreator.createSampleData(in: CoreDataManager.shared.viewContext)
```

### 3. Tests ausführen
```swift
// Development-Tests
#if DEBUG
GPSTestScript.shared.quickTest()
#endif
```

Das komplette GPS-Tracking System ist **production-ready** und kann sofort verwendet werden! 🚀📍 