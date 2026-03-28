# PC-Umzug Status

## Verbindungsdaten
- Alter PC (Win 10): IP `192.168.1.37`, Hostname `DESKTOP-D4398S0`, User `user`, PW `Kinderschutz`
- Neuer PC (Win 11): Claude Code Desktop

## Erledigte Schritte
- [x] Migrations-Scripts erstellt und auf GitHub gepusht
- [x] Netzwerk-Shares auf altem PC eingerichtet (SMB, Firewall)
- [x] PSRemoting auf altem PC aktiviert
- [x] PSRemoting + WinRM auf neuem PC aktiviert
- [x] TrustedHosts auf neuem PC gesetzt
- [x] Verbindung via PSRemoting erfolgreich (184 Programme gefunden)
- [x] Scripts nach C:\Migration\ heruntergeladen

## Offene Punkte (morgen fortsetzen)
- [ ] SMB-Share Authentifizierung: `net use \\192.168.1.37\C_Umzug /user:user Kinderschutz`
- [ ] Master-Script erneut starten mit Programmauswahl (Fenster im Vordergrund beachten!)
- [ ] Dateien kopieren (Desktop: 20 GB, Dokumente: 14 GB, Downloads: 2 GB)
- [ ] Programme selektiv installieren via winget

## Morgen starten mit (neuer PC, PowerShell als Admin)

### Schritt 1 - Share authentifizieren:
```powershell
net use \\192.168.1.37\C_Umzug /user:user Kinderschutz
```

### Schritt 2 - Migration starten:
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Migration\master.ps1" -AlterPcIP "192.168.1.37" -AlterPcUser "user"
```
Passwort: Kinderschutz
Achtung: Auswahl-Fenster (Programme + Ordner) koennen in der Taskleiste erscheinen!

## Dateigroessen alter PC
- Desktop:   20.5 GB
- Dokumente: 14.9 GB
- Downloads:  2.5 GB
- Bilder:     1.3 MB
- Musik:      0 MB
- Videos:     0 MB
