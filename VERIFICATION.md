# Prüfprotokoll

Stand: 12. Oktober 2026

## Quellcode

- Flutter 3.44.9 stable / Dart 3.12.2
- `flutter analyze --no-pub`: **No issues found**
- `flutter test --no-pub`: **13 Tests bestanden**

Die Tests prüfen:

- exakt 390 eindeutige Episoden
- die erwarteten fünf Reihen mit 196/50/21/108/15 Einträgen
- Edition-2000-Folge 196 „Die Maske“ vom 28. August 2026
- verlustfreies Aktualisieren des lokalen Hörstatus
- Kompilierbarkeit aller Hauptseiten
- Navigation von der Episodenliste zu einer datierten Detailseite einschließlich
  korrekter deutscher Datumsanzeige
- Erkennung und lokales Zusammenführen neuer Folgen aus den offiziellen
  Serienseiten
- persistente Speicherung von Designmodus und gewählter Akzentfarbe
- persistente Wiederherstellung von Sortierung, Gehört-Filter,
  Mindestbewertung, Suchtext und aktiver Reihe nach einem Neustart
- quadratische Coverrahmen und vollständige Darstellung ohne Beschnitt

## Datenabdeckung

- 390 Katalogeinträge vorhanden
- 384 Einträge mit offiziellem Cover und offizieller Inhaltsangabe verknüpft
- fehlende Cover werden in der Oberfläche durch einen neutralen Platzhalter ersetzt

## Android-Release

- Build: Flutter 3.44.9 stable / Dart 3.12.2 / Temurin JDK 17.0.20.1
- APK: `Sinclair-Tracker-v1.1.1.apk` (58.253.525 Byte)
- SHA-256: `75b620481cbc0fb454be3d7d8863c135d830e5758779b8f5e7ef2b83654c7902`
- Paket: `app.sinclairtracker.unofficial`, Version 1.1.1 (Code 4)
- App-Name: „Sinclair Tracker“
- Mindest-SDK: 24 (Android 7.0), Ziel-/Compile-SDK: 36
- Architekturen: arm64-v8a, armeabi-v7a und x86_64
- `apksigner verify --verbose --print-certs`: APK-v2-Signatur gültig
- `unzip -t`: keine Fehler im APK-Archiv
- Zertifikat SHA-256:
  `D4:6F:9D:08:C2:09:05:6F:13:84:0A:DE:52:CD:82:04:D1:56:84:C8:29:51:3D:F9:6E:47:09:32:65:0B:A3:5F`

Die APK ist ein Release-Mode-Build und mit dem dauerhaft gesicherten,
projektspezifischen Release-Zertifikat signiert. Sie ist für Sideloading
geeignet. Version 1.0.1 verwendete noch einen verlorenen Debugschlüssel und muss
daher nach einem JSON-Export einmalig deinstalliert werden. Ab Version 1.1.0
sind direkte Updates mit diesem Release-Zertifikat möglich.

Der reproduzierbare GitHub-Actions-Lauf `Android release #1` hat Analyse, Tests,
Build, Archiv- und Signaturprüfung erfolgreich abgeschlossen und die APK mit
Prüfsumme als GitHub Release `v1.1.1` veröffentlicht.
