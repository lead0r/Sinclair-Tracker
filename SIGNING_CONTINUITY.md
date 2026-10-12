# Signatur und künftige Updates

Sinclair Tracker wird ab Version 1.1.0 mit einem dauerhaft aufbewahrten,
projektspezifischen Schlüssel signiert. Das zugehörige private Archiv heißt
`Sinclair-Tracker-signing-private.zip` und darf nicht veröffentlicht oder einem
öffentlichen Quellcode-Repository hinzugefügt werden.

Zertifikat SHA-256 ab Version 1.1.0:

`D4:6F:9D:08:C2:09:05:6F:13:84:0A:DE:52:CD:82:04:D1:56:84:C8:29:51:3D:F9:6E:47:09:32:65:0B:A3:5F`

Künftige APKs mit der Paketkennung `app.sinclairtracker.unofficial` müssen mit
diesem Schlüssel signiert werden, damit Android sie als Update akzeptiert.

Die Versionen 1.0.0 und 1.0.1 verwendeten einen inzwischen verlorenen lokalen
Debugschlüssel. Deshalb ist einmalig vor dem Wechsel von 1.0.1 ein JSON-Backup
zu exportieren. Danach wird 1.0.1 deinstalliert, 1.1.0 installiert und das
JSON-Backup importiert. Ab 1.1.0 sind direkte Updates wieder möglich.
