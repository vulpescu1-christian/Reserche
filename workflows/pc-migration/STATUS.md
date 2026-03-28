# PC-Umzug Status

## Verbindungsdaten
- Alter PC (Win 10): IP `192.168.1.37`, Hostname `DESKTOP-D4398S0`, User `user`
- Neuer PC (Win 11): Claude Code Desktop, Benutzer `AURUMPC`
- Temporäres Netzwerkpasswort (alter PC): `Migration2026` → nach Abschluss entfernen mit `net user user ""`

## Erledigte Schritte

### Netzwerk & Verbindung
- [x] Migrations-Scripts erstellt und auf GitHub gepusht
- [x] Netzwerk-Shares auf altem PC eingerichtet (SMB, Firewall)
- [x] PSRemoting auf altem PC aktiviert
- [x] PSRemoting + WinRM auf neuem PC aktiviert
- [x] Temporäres Passwort auf altem PC gesetzt: `net user user Migration2026`
- [x] SMB-Verbindung erfolgreich: `net use \\192.168.1.37\C_Umzug /user:user Migration2026`

### Datei-Migration (28.03.2026)
- [x] Desktop (20 GB, 4240 Dateien) → `C:\Users\AURUMPC\Desktop`
- [x] Dokumente (14.5 GB) → `C:\Users\AURUMPC\Documents`
- [x] Downloads (2.4 GB) → `C:\Users\AURUMPC\Downloads`
- [x] Bilder (1.3 MB) → `C:\Users\AURUMPC\Pictures`
- [x] D:\ persönliche Ordner → `C:\Umzug_Alt\` (Bildbearbeitung, Bilder_Rotary_Ego, Kalenderbilder, Toshiba-Umzug, Umzug2019, Klaus_Bild, Niklas_Bild, DNA_Linea_Fit, Office-Vorlagen, PSAutoRecover, etc.)
- [x] D:\ Root-Dateien → `C:\Umzug_Alt\_Root_D\`

### Programme (28.03.2026)
- [x] Microsoft Teams installiert (winget)
- [x] Programme_Review.txt erstellt in Documents
- [x] Desktop_Sortierung_Protokoll.txt erstellt in Documents

### Desktop-Sortierung (28.03.2026)
- [x] Sortierung_Wichtig erstellt (Arbeitsverträge, Dokumente, Fotos, etc.)
- [x] Sortierung_Unschluessig erstellt (Lebensläufe, alte Präsentationen, etc.)
- [x] Sortierung_Veraltet_oder_Ueberfluessig erstellt (Windows.iso 4GB, alte HTMs, etc.)

## Noch offen

### Daten
- [ ] Prüfen ob E:, G:, I: Laufwerke auf altem PC vorhanden und relevant
- [ ] `net view \\192.168.1.37` ausführen um alle Shares zu sehen

### Programme
- [ ] HP DeskJet 4220e Druckertreiber installieren (Einstellungen → Drucker & Scanner)
- [ ] Chrome-Profil synchronisieren (Google-Account in Chrome einloggen)
- [ ] Firefox-Lesezeichen synchronisieren (Firefox-Account oder manuell)
- [ ] Windows Credential Manager: Passwörter manuell neu eingeben

### Aufräumen
- [ ] Temporäres Passwort vom alten PC entfernen: `net user user ""`
- [ ] SMB-Shares vom alten PC entfernen (optional)
- [ ] `C:\Migration_Inventar\` auf neuem PC prüfen und ggf. löschen

## Speicherorte neue Daten (neuer PC)
```
C:\Users\AURUMPC\Desktop          ← Desktop vom alten PC
C:\Users\AURUMPC\Documents        ← Dokumente vom alten PC
C:\Users\AURUMPC\Downloads        ← Downloads vom alten PC
C:\Users\AURUMPC\Pictures         ← Bilder vom alten PC
C:\Umzug_Alt\                     ← D:\ Inhalte vom alten PC
C:\Umzug_Alt\_Root_D\             ← Einzeldateien D:\ Root
C:\Users\AURUMPC\Documents\Sortierung_Wichtig\
C:\Users\AURUMPC\Documents\Sortierung_Unschluessig\
C:\Users\AURUMPC\Documents\Sortierung_Veraltet_oder_Ueberfluessig\
C:\Users\AURUMPC\Documents\Desktop_Sortierung_Protokoll.txt
C:\Users\AURUMPC\Documents\Programme_Review.txt
```

## Robocopy Logs
Alle Logs gespeichert unter: `C:\Migration_Inventar\`
