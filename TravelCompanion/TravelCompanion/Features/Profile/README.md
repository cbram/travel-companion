# Benutzerverwaltung - Travel Companion

Die Benutzerverwaltung ermöglicht es mehreren Benutzern, die Travel Companion App zu verwenden und zwischen Profilen zu wechseln.

## Features

### ✅ Vollständig implementiert:

1. **Benutzerregistrierung** (`UserRegistrationView.swift`)
   - E-Mail und Name erforderlich
   - Optional: Avatar URL
   - E-Mail Validierung
   - Automatische Anmeldung nach Registrierung

2. **Benutzerauswahl** (`UserSelectionView.swift`)
   - Übersicht aller aktiven Benutzer
   - Benutzerstatistiken (Reisen, Erinnerungen)
   - Schnelle Anmeldung
   - Neuen Benutzer erstellen

3. **Benutzerprofil** (`UserProfileView.swift`)
   - Detaillierte Profilansicht
   - Benutzerstatistiken
   - Profil bearbeiten
   - Benutzer wechseln
   - Benutzer deaktivieren

4. **Profil bearbeiten** (`EditUserProfileView.swift`)
   - Name ändern
   - Avatar URL aktualisieren
   - E-Mail anzeigen (nicht änderbar)
   - Sofortige Vorschau

5. **Authentifizierung** (`AuthenticationState.swift`)
   - Anmeldestatus verwalten
   - Automatische Status-Updates
   - Session-Management

6. **App-Wrapper** (`AuthenticatedApp.swift`)
   - Loading Screen
   - Automatische Navigation
   - Fehlerbehandlung

## Verwendung

### App-Start:
1. App prüft automatisch den Anmeldestatus
2. Wenn kein Benutzer angemeldet → Benutzerauswahl
3. Wenn Benutzer angemeldet → Hauptapp

### Benutzer wechseln:
1. Einstellungen → Benutzerprofil
2. "Benutzer wechseln" auswählen
3. Neuen Benutzer auswählen oder erstellen

### Neuen Benutzer erstellen:
1. Benutzerauswahl → "Neuen Benutzer erstellen"
2. Name und E-Mail eingeben
3. Optional: Avatar URL
4. Automatische Anmeldung

## Technische Details

### Datenmodell:
- Verwendet bestehende `User` Core Data Entity
- Alle User-Extensions bereits verfügbar
- Statistiken werden automatisch berechnet

### Navigation:
- Modular aufgebaut mit SwiftUI Sheets
- `@EnvironmentObject` für Datenfluss
- Automatische UI-Updates

### State Management:
- `AuthenticationState`: Zentrale Authentifizierung
- `UserManager`: Core Data Operationen
- Reactive UI mit `@Published` Properties

## Integration in bestehende App

Die Benutzerverwaltung ist bereits in die bestehende App integriert:

1. **TravelCompanionApp.swift**: Verwendet `AuthenticatedApp` als Root View
2. **SettingsView.swift**: Erweitert um Benutzerprofilintegration
3. **ContentView.swift**: Bleibt unverändert, wird nur bei authentifizierten Benutzern angezeigt

## Nächste Schritte

Mögliche Erweiterungen:
- [ ] Passwort-Schutz für Benutzer
- [ ] Biometrische Authentifizierung
- [ ] Cloud-Synchronisation zwischen Geräten
- [ ] Benutzergruppen/Familien-Accounts
- [ ] Export/Import von Benutzerdaten

## Dateien Übersicht

```
Features/Profile/
├── AuthenticationState.swift      # Authentifizierungs-Logic
├── AuthenticatedApp.swift         # App-Wrapper
├── UserRegistrationView.swift     # Neue Benutzer erstellen
├── UserSelectionView.swift        # Benutzer auswählen
├── UserProfileView.swift          # Profilansicht
├── EditUserProfileView.swift      # Profil bearbeiten
└── SettingsView.swift            # Erweiterte Einstellungen
```

Die Benutzerverwaltung ist vollständig funktionsfähig und einsatzbereit! 🎉 