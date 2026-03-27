# ============================================================
# SCHRITT 2: Auf dem NEUEN PC (Windows 11) ausfuehren
# Interaktive Auswahl: Was soll migriert werden?
# ============================================================

param(
    [string]$AlterPcIP   = "",   # IP des alten PCs (z.B. 192.168.0.10)
    [string]$AusgabePfad = "C:\Migration_Inventar"
)

if (-not $AlterPcIP) {
    $AlterPcIP = Read-Host "IP-Adresse des alten PCs eingeben (z.B. 192.168.0.10)"
}

# Inventar-Datei direkt vom Netzwerk-Share des alten PCs lesen
$InventarPfad = "\\$AlterPcIP\C_Umzug\Migration_Inventar\inventar.json"

if (-not (Test-Path $InventarPfad)) {
    Write-Host "FEHLER: Inventar-Datei nicht erreichbar: $InventarPfad" -ForegroundColor Red
    Write-Host "Sicherstellen dass:"
    Write-Host "  1. 00_setup_shares_alter_pc.ps1 auf dem alten PC ausgefuehrt wurde"
    Write-Host "  2. 01_scan_old_pc.ps1 auf dem alten PC ausgefuehrt wurde"
    Write-Host "  3. Der alte PC erreichbar ist: ping $AlterPcIP"
    exit 1
}

Write-Host "=== PC-Umzug: Auswahl treffen ===" -ForegroundColor Cyan
$inventar = Get-Content $InventarPfad -Encoding UTF8 | ConvertFrom-Json
Write-Host "Alter PC:   $($inventar.Hostname) | $($inventar.WindowsVersion)"
Write-Host "Erstellt:   $($inventar.ErstelltAm)"
Write-Host "Programme:  $($inventar.Programme.Count)"

# ------------------------------------------------------------
# Programme interaktiv auswaehlen (Out-GridView Fenster)
# ------------------------------------------------------------
Write-Host "`n[1/2] Programmauswahl wird geoeffnet..." -ForegroundColor Yellow
Write-Host "  -> Gewuenschte Programme markieren (Strg+Klick fuer mehrere) -> OK klicken"

$ausgewaehlteProgramme = $inventar.Programme |
    Select-Object Name, Version, Publisher, Groesse_MB, WingetID |
    Sort-Object Name |
    Out-GridView -Title "Programme auswaehlen (STRG+Klick = mehrere auswählen, dann OK)" -PassThru

Write-Host "  $($ausgewaehlteProgramme.Count) Programme ausgewaehlt."

# ------------------------------------------------------------
# Ordner auswaehlen
# ------------------------------------------------------------
Write-Host "`n[2/2] Ordner-Auswahl wird geoeffnet..." -ForegroundColor Yellow

$ausgewaehlteOrdner = $inventar.Ordner |
    Select-Object Name, Pfad, Groesse_MB |
    Out-GridView -Title "Ordner auswaehlen (STRG+Klick = mehrere auswählen, dann OK)" -PassThru

Write-Host "  $($ausgewaehlteOrdner.Count) Ordner ausgewaehlt."

# ------------------------------------------------------------
# Auswahl speichern
# ------------------------------------------------------------
New-Item -ItemType Directory -Path $AusgabePfad -Force | Out-Null

$auswahl = [PSCustomObject]@{
    AuswahlDatum = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    AlterPcIP    = $AlterPcIP
    Programme    = $ausgewaehlteProgramme
    Ordner       = $ausgewaehlteOrdner
}

$auswahlPfad = Join-Path $AusgabePfad "auswahl.json"
$auswahl | ConvertTo-Json -Depth 5 | Out-File -FilePath $auswahlPfad -Encoding UTF8

Write-Host "`n=== Auswahl gespeichert! ===" -ForegroundColor Green
Write-Host "Datei: $auswahlPfad"
Write-Host "Naechster Schritt: 03_migration_durchfuehren.ps1 ausfuehren."
