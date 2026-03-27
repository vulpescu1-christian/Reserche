# PC-Umzug: Windows 10 → Windows 11 (selektiv)

## Voraussetzung
- Alter PC (Win 10) und neuer PC (Win 11) per LAN-Kabel verbunden
- PowerShell als **Administrator** starten

---

## Ablauf

### Schritt 0 – Shares auf altem PC einrichten
**Auf dem ALTEN PC (Win 10)** als Administrator:
```powershell
powershell -ExecutionPolicy Bypass -File 00_setup_shares_alter_pc.ps1
```
→ Gibt die IP-Adresse des alten PCs aus → diese IP merken!

---

### Schritt 1 – Alten PC scannen
**Auf dem ALTEN PC (Win 10)** als Administrator:
```powershell
powershell -ExecutionPolicy Bypass -File 01_scan_old_pc.ps1
```
→ Erstellt `C:\Migration_Inventar\inventar.json`

---

### Schritt 2 – Auswahl treffen
**Auf dem NEUEN PC (Win 11)** als Administrator:
```powershell
powershell -ExecutionPolicy Bypass -File 02_auswahl_treffen.ps1 -AlterPcIP "192.168.x.x"
```
→ Liest das Inventar direkt vom Netzwerk-Share des alten PCs
→ Öffnet zwei Auswahl-Fenster:
- **Programme**: Was soll auf dem neuen PC installiert werden?
- **Ordner**: Desktop, Dokumente, Bilder, etc.

→ Speichert `C:\Migration_Inventar\auswahl.json`

---

### Schritt 3 – Migration durchführen
**Auf dem NEUEN PC (Win 11)** als Administrator:
```powershell
powershell -ExecutionPolicy Bypass -File 03_migration_durchfuehren.ps1
```
→ Installiert ausgewählte Programme via **winget**
→ Kopiert ausgewählte Ordner via **robocopy** über das Netzwerk-Share
→ Erstellt Protokoll: `C:\Migration_Inventar\protokoll.csv`

---

## Hinweise
- Programme **ohne winget-ID** → manuell installieren (im Protokoll aufgelistet)
- Lizenzierte Software (Adobe, Office, etc.) → ggf. neu aktivieren
- robocopy Exit-Code < 8 = erfolgreich (Codes 0–7 sind OK)
