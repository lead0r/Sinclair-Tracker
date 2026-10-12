# Sinclair Tracker

Inoffizielle Android-App zum Verwalten gehörter **John-Sinclair-Hörspiele**.
Der Tracker ist ein eigenständiger Flutter-Fork des MIT-lizenzierten
[DDF Tracker](https://github.com/lead0r/DDF-Tracker).

## Enthaltener Katalog

| Reihe | Folgen |
| --- | ---: |
| Edition 2000 | 196 |
| Sinclair Classics | 50 |
| Sondereditionen | 21 |
| Tonstudio Braun | 108 |
| SINCLAIR (Dead Zone & Underworld) | 15 |
| **Gesamt** | **390** |

Stand des gebündelten Katalogs: 2. September 2026. Folge 196 der Edition 2000
ist „Die Maske“ (28. August 2026).

Beim Öffnen prüft die App höchstens einmal in 24 Stunden die sechs offiziellen
Serienseiten. Neue und bereits angekündigte Folgen werden ergänzt und lokal
gespeichert. Die manuelle Prüfung befindet sich unter **Einstellungen & Backup →
Episodenkatalog**. Ohne Internet bleibt der zuletzt gespeicherte Stand nutzbar.

## Funktionen

- gehört/ungehört markieren, 1–5 Sterne vergeben und Notizen speichern
- getrennte Tabs für alle fünf Reihen
- Suche, Filter und Sortierung
- Sortierung, Filter, Suchtext und zuletzt geöffnete Reihe bleiben nach einem
  Neustart erhalten
- Detailseiten mit Inhaltsangaben sowie Anbieter- und Produktlinks
- Statistiken und Zufallsfolge
- dauerhaftes SQLite-Speichern auf dem Gerät
- JSON-Backup und -Wiederherstellung
- optionaler Offline-Download der Cover
- quadratische, vollständig sichtbare Cover ohne erzwungenen Hochkant-Beschnitt
- automatischer Katalogabgleich sowie Schaltfläche „Jetzt prüfen“
- helles, dunkles oder systemabhängiges Design
- sechs dauerhaft gespeicherte Akzentfarben: Blutrot, Violett, Magenta,
  Nachtblau, Smaragd und Silber
- eigenes Kreuzsymbol in Kopfzeile, Einstellungen und App-Symbol

## Daten aktualisieren

```bash
python3 -m pip install -r tools/requirements.txt
python3 tools/update_episode_data.py
dart run tools/live_catalog_check.dart
```

Der Generator erneuert den gebündelten Basiskatalog. Zusätzlich aktualisiert
Version 1.1.0 den Katalog direkt in der App. Details und Quellen stehen in
[DATA_SOURCES.md](DATA_SOURCES.md).

## Entwicklung und APK

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --flavor standard --release
```

Ohne eigene `android/key.properties` wird der Standard-Flavor mit dem lokalen
Debug-Schlüssel signiert und bleibt damit direkt installierbar. Für eine
öffentliche Veröffentlichung sollte ein eigener, sicher verwahrter
Release-Schlüssel verwendet werden.

Die ab Version 1.1.0 verwendete Signatur und die einmalige Migration von 1.0.1
sind in [SIGNING_CONTINUITY.md](SIGNING_CONTINUITY.md) dokumentiert.

Die geprüfte APK 1.1.1 unterstützt Android 7.0/API 24 und neuer. Sie enthält
arm64-v8a, armeabi-v7a und x86_64 und zielt auf Android API 36. APK und
SHA-256-Prüfsumme stehen im
[GitHub Release v1.1.1](https://github.com/lead0r/Sinclair-Tracker/releases/tag/v1.1.1).

## Rechtehinweis

Sinclair Tracker ist ein nicht kommerzielles Fanprojekt ohne Verbindung zu
Bastei Lübbe, Lübbe Audio oder Jason Dark. „John Sinclair“ und zugehörige
Kennzeichen, Cover und Texte gehören ihren jeweiligen Rechteinhabern. Das
App-Symbol ist eine eigenständige, generische Gestaltung und verwendet kein
offizielles Logo.

Der Programmcode steht unter der bestehenden [MIT-Lizenz](LICENSE). Die Lizenz
erstreckt sich nicht auf fremde Episodenmetadaten, Beschreibungen oder Cover.
