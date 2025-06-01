# CoreGraphics NaN-Fehler Behebung

## 🐛 Problem
Beim Speichern von Erinnerungen auf dem iPhone traten wiederholte CoreGraphics-Fehler auf:

```
Error: this application, or a library it uses, has passed an invalid numeric value (NaN, or not-a-number) to CoreGraphics API and this value is being ignored.
```

## 🔍 Ursachenanalyse

Die NaN-Fehler entstanden durch mehrere Quellen:

### 1. **horizontalAccuracy-Anzeige in UI**
- `CLLocation.horizontalAccuracy` kann negative Werte oder NaN enthalten
- Direkte Verwendung in `Text("±\(Int(location.horizontalAccuracy))m")` führte zu NaN in CoreGraphics
- **Problem-Code:**
```swift
Text("Genauigkeit: ±\(Int(location.horizontalAccuracy))m")
```

### 2. **Bildkomprimierung ohne Validierung**
- `UIGraphicsBeginImageContextWithOptions()` erhielt ungültige CGSize-Werte
- Division durch Null oder NaN in Größenberechnungen
- **Problem-Code:**
```swift
let ratio = maxDimension / max(size.width, size.height)
let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
```

### 3. **Ungültige Koordinaten in Core Data**
- Koordinaten wurden ohne Validierung gespeichert
- NaN-Werte konnten in latitude/longitude gelangen

## ✅ Implementierte Lösungen

### 1. **LocationValidator Utility-Klasse**
Neue zentrale Validierungsklasse für alle Location-bezogenen Operationen:

```swift
struct LocationValidator {
    static func isValidCoordinate(latitude: Double, longitude: Double) -> Bool
    static func isValidLocation(_ location: CLLocation?) -> Bool
    static func sanitizeCoordinates(latitude: Double, longitude: Double) -> (lat: Double, lon: Double)
    static func formatAccuracy(_ accuracy: Double) -> String
    static func formatCoordinates(latitude: Double, longitude: Double, precision: Int = 6) -> String
}
```

### 2. **Sichere UI-Darstellung**
**Vorher:**
```swift
Text("Genauigkeit: ±\(Int(location.horizontalAccuracy))m")
```

**Nachher:**
```swift
Text("Genauigkeit: \(location.formattedAccuracy)")
    .foregroundColor(location.horizontalAccuracy >= 0 ? .secondary : .orange)
```

### 3. **Validierte Bildkomprimierung**
**Vorher:**
```swift
let ratio = maxDimension / max(size.width, size.height)
let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
```

**Nachher:**
```swift
// Validiere die ursprüngliche Bildgröße
guard size.width.isFinite && size.height.isFinite && 
      size.width > 0 && size.height > 0 else {
    return image
}

let maxCurrentDimension = max(size.width, size.height)
guard maxCurrentDimension.isFinite && maxCurrentDimension > 0 else {
    return image
}

let ratio = maxDimension / maxCurrentDimension
guard ratio.isFinite && ratio > 0 else {
    return image
}

let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
guard newSize.width.isFinite && newSize.height.isFinite &&
      newSize.width > 0 && newSize.height > 0 else {
    return image
}

UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
```

### 4. **Koordinaten-Validierung in ViewModels**
```swift
// Vor Core Data Speicherung
let lat = currentLocation?.coordinate.latitude ?? 0.0
let lon = currentLocation?.coordinate.longitude ?? 0.0

guard LocationValidator.isValidCoordinate(latitude: lat, longitude: lon) else {
    showError("Ungültige GPS-Koordinaten. Bitte aktualisiere deinen Standort.")
    return
}
```

### 5. **Sichere Core Data Model Extensions**
```swift
extension Memory {
    var location: CLLocation {
        // Validiere Koordinaten bevor CLLocation erstellt wird
        let lat = latitude.isFinite ? latitude : 0.0
        let lon = longitude.isFinite ? longitude : 0.0
        
        let validLat = max(-90.0, min(90.0, lat))
        let validLon = max(-180.0, min(180.0, lon))
        
        return CLLocation(latitude: validLat, longitude: validLon)
    }
}
```

### 6. **CLLocation Extensions**
```swift
extension CLLocation {
    var isValid: Bool {
        return LocationValidator.isValidLocation(self)
    }
    
    var formattedCoordinates: String {
        return LocationValidator.formatCoordinates(...)
    }
    
    var formattedAccuracy: String {
        return LocationValidator.formatAccuracy(horizontalAccuracy)
    }
}
```

## 🛠️ Veränderte Dateien

1. **Neue Dateien:**
   - `TravelCompanion/Utils/LocationValidator.swift`

2. **Aktualisierte Dateien:**
   - `Features/Memories/MemoryCreationView.swift`
   - `Features/Memories/EnhancedMemoryCreationView.swift`
   - `Features/Memories/MemoryCreationViewModel.swift`
   - `Features/Memories/EnhancedMemoryCreationViewModel.swift`
   - `Core/CoreData/Models/Memory+Extensions.swift`

## 🧪 Tests

Um die Behebung zu testen:

1. **NaN-Koordinaten Test:**
```swift
let invalidLat = Double.nan
let invalidLon = Double.infinity
assert(!LocationValidator.isValidCoordinate(latitude: invalidLat, longitude: invalidLon))
```

2. **Bildkomprimierung Test:**
```swift
let invalidImage = UIImage() // Erstelle Image mit ungültigen Dimensionen
let result = compressImageForStorage(invalidImage)
// Sollte Original-Image zurückgeben ohne Crash
```

3. **UI horizontalAccuracy Test:**
```swift
let invalidLocation = CLLocation(...) // mit horizontalAccuracy = -1 oder NaN
let formatted = invalidLocation.formattedAccuracy
assert(formatted == "Unbekannt")
```

## 📱 Erwartetes Verhalten nach Fix

- ✅ Keine CoreGraphics NaN-Fehler mehr
- ✅ Graceful Handling ungültiger GPS-Daten
- ✅ Sichere Bildkomprimierung ohne Crashes
- ✅ Robuste Koordinaten-Validierung
- ✅ Benutzerfreundliche Fehlermeldungen bei ungültigen Daten

## 🚀 Prevention für Zukunft

1. **Immer LocationValidator verwenden** für Location-Operations
2. **Alle numerischen Werte validieren** bevor sie an CoreGraphics weitergegeben werden
3. **CLLocation Extensions nutzen** für sichere UI-Formatierung
4. **Guard-Statements verwenden** für kritische numerische Operationen
5. **Unit Tests** für Edge-Cases mit NaN/Infinity-Werten 