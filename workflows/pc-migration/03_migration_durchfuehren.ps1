# ============================================================
# SCHRITT 3: Auf dem NEUEN PC (Windows 11) ausfuehren
# Fuehrt die selektive Migration durch
# Als Administrator starten!
# ============================================================

param(
    [string]$AuswahlPfad   = "C:\Migration_Inventar\auswahl.json",
    [string]$ZielBasisPfad = "C:\Users\$env:USERNAME"
)

if (-not (Test-Path $AuswahlPfad)) {
    Write-Host "FEHLER: Auswahl-Datei nicht gefunden: $AuswahlPfad" -ForegroundColor Red
    Write-Host "Zuerst 02_auswahl_treffen.ps1 ausfuehren."
    exit 1
}

$auswahl   = Get-Content $AuswahlPfad -Encoding UTF8 | ConvertFrom-Json
$AlterPcIP = $auswahl.AlterPcIP

Write-Host "=== PC-Umzug: Migration startet ===" -ForegroundColor Cyan
Write-Host "Alter PC IP: $AlterPcIP"
Write-Host "Programme:   $($auswahl.Programme.Count)"
Write-Host "Ordner:      $($auswahl.Ordner.Count)"

$protokoll = @()

# ------------------------------------------------------------
# 1. Programme installieren (via winget)
# ------------------------------------------------------------
Write-Host "`n[1/2] Programme installieren..." -ForegroundColor Yellow

foreach ($prog in $auswahl.Programme) {
    if ($prog.WingetID) {
        Write-Host "  Installiere: $($prog.Name) ($($prog.WingetID))..." -NoNewline
        $result = winget install --id $prog.WingetID --silent --accept-source-agreements --accept-package-agreements 2>&1
        $erfolg = $LASTEXITCODE -eq 0
        Write-Host $(if ($erfolg) { " OK" } else { " FEHLER" }) -ForegroundColor $(if ($erfolg) { "Green" } else { "Red" })
        $protokoll += [PSCustomObject]@{
            Typ     = "Programm"
            Name    = $prog.Name
            Methode = "winget ($($prog.WingetID))"
            Status  = if ($erfolg) { "OK" } else { "FEHLER" }
            Hinweis = if (-not $erfolg) { ($result | Select-Object -Last 1) } else { "" }
        }
    } else {
        Write-Host "  KEIN WINGET: $($prog.Name) -> manuell installieren" -ForegroundColor DarkYellow
        $protokoll += [PSCustomObject]@{
            Typ     = "Programm"
            Name    = $prog.Name
            Methode = "Manuell"
            Status  = "AUSSTEHEND"
            Hinweis = "Kein winget-Eintrag - bitte manuell installieren"
        }
    }
}

# ------------------------------------------------------------
# 2. Ordner kopieren via robocopy ueber Netzwerk-Share
# ------------------------------------------------------------
Write-Host "`n[2/2] Dateien kopieren..." -ForegroundColor Yellow

$ordnerMap = @{
    "Desktop"   = "Desktop"
    "Dokumente" = "Documents"
    "Downloads" = "Downloads"
    "Bilder"    = "Pictures"
    "Musik"     = "Music"
    "Videos"    = "Videos"
}

foreach ($ordner in $auswahl.Ordner) {
    # Netzwerk-Share Pfad berechnen
    $laufwerk         = (Split-Path $ordner.Pfad -Qualifier).TrimEnd(':')
    $shareName        = "${laufwerk}_Umzug"
    $relPfad          = $ordner.Pfad -replace [regex]::Escape((Split-Path $ordner.Pfad -Qualifier) + "\"), ""
    $quelle           = "\\$AlterPcIP\$shareName\$relPfad"

    # Ziel-Ordner bestimmen
    $zielName         = if ($ordnerMap.ContainsKey($ordner.Name)) { $ordnerMap[$ordner.Name] } else { $ordner.Name }
    $ziel             = Join-Path $ZielBasisPfad $zielName
    $logDatei         = "C:\Migration_Inventar\robocopy_$($ordner.Name).log"

    Write-Host "  Kopiere $($ordner.Name) ($($ordner.Groesse_MB) MB)..."
    Write-Host "    Von:  $quelle"
    Write-Host "    Nach: $ziel"

    robocopy $quelle $ziel /E /COPYALL /R:2 /W:3 /NP /LOG+:$logDatei | Out-Null
    $rc     = $LASTEXITCODE
    $erfolg = $rc -lt 8  # robocopy: Exit-Code < 8 = OK

    Write-Host "    $(if ($erfolg) { 'OK' } else { "FEHLER (Code $rc) - Log: $logDatei" })" -ForegroundColor $(if ($erfolg) { "Green" } else { "Red" })

    $protokoll += [PSCustomObject]@{
        Typ     = "Ordner"
        Name    = $ordner.Name
        Methode = "robocopy"
        Status  = if ($erfolg) { "OK" } else { "FEHLER (Code $rc)" }
        Hinweis = if (-not $erfolg) { "Log: $logDatei" } else { "" }
    }
}

# ------------------------------------------------------------
# Protokoll speichern und Zusammenfassung anzeigen
# ------------------------------------------------------------
$protokollPfad = "C:\Migration_Inventar\protokoll.csv"
$protokoll | Export-Csv -Path $protokollPfad -Encoding UTF8 -NoTypeInformation

Write-Host "`n=== Migration abgeschlossen! ===" -ForegroundColor Green
Write-Host "Protokoll: $protokollPfad"
Write-Host ""

$ok         = @($protokoll | Where-Object { $_.Status -eq "OK" }).Count
$fehler     = @($protokoll | Where-Object { $_.Status -like "FEHLER*" })
$ausstehend = @($protokoll | Where-Object { $_.Status -eq "AUSSTEHEND" })

Write-Host "  Erfolgreich:  $ok" -ForegroundColor Green
Write-Host "  Fehler:       $($fehler.Count)" -ForegroundColor $(if ($fehler.Count -gt 0) { "Red" } else { "Green" })
Write-Host "  Manuell noetig: $($ausstehend.Count)" -ForegroundColor $(if ($ausstehend.Count -gt 0) { "Yellow" } else { "Green" })

if ($fehler.Count -gt 0) {
    Write-Host "`nFehler-Details:" -ForegroundColor Red
    $fehler | ForEach-Object { Write-Host "  - $($_.Name): $($_.Hinweis)" -ForegroundColor Red }
}
if ($ausstehend.Count -gt 0) {
    Write-Host "`nManuell installieren:" -ForegroundColor Yellow
    $ausstehend | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Yellow }
}
