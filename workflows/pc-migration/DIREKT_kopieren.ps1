# ============================================================
# DIREKT KOPIEREN - Kein PSRemoting noetig!
# Auf dem NEUEN PC (Win 11) als Administrator ausfuehren
# Kopiert Dateien direkt ueber SMB-Share
# ============================================================

param(
    [string]$AlterPcIP     = "192.168.1.37",
    [string]$AlterPcUser   = "user",
    [string]$AlterPcPW     = "Kinderschutz",
    [string]$ZielBasisPfad = "C:\Users\$env:USERNAME"
)

Write-Host "=== Direktkopie vom alten PC ===" -ForegroundColor Cyan
Write-Host "Alter PC: $AlterPcIP"

# 1. Authentifizieren (alle Laufwerke)
Write-Host "`n[1/3] Authentifiziere Netzwerk-Shares..." -ForegroundColor Yellow
$shares = @("C_Umzug","D_Umzug","E_Umzug","G_Umzug","I_Umzug")
foreach ($share in $shares) {
    net use "\\$AlterPcIP\$share" /user:$AlterPcUser $AlterPcPW /persistent:no 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  $share: OK" -ForegroundColor Green
    }
}

# 2. Ordner zum Kopieren auswaehlen
Write-Host "`n[2/3] Ordner auswaehlen..." -ForegroundColor Yellow

$AlterBenutzer = Read-Host "Benutzername auf altem PC (Enter fuer 'user')"
if (-not $AlterBenutzer) { $AlterBenutzer = "user" }

$quellen = @(
    [PSCustomObject]@{ Name="Desktop";   Quelle="\\$AlterPcIP\C_Umzug\Users\$AlterBenutzer\Desktop";   Ziel=Join-Path $ZielBasisPfad "Desktop"    }
    [PSCustomObject]@{ Name="Dokumente"; Quelle="\\$AlterPcIP\C_Umzug\Users\$AlterBenutzer\Documents"; Ziel=Join-Path $ZielBasisPfad "Documents"  }
    [PSCustomObject]@{ Name="Downloads"; Quelle="\\$AlterPcIP\C_Umzug\Users\$AlterBenutzer\Downloads"; Ziel=Join-Path $ZielBasisPfad "Downloads"  }
    [PSCustomObject]@{ Name="Bilder";    Quelle="\\$AlterPcIP\C_Umzug\Users\$AlterBenutzer\Pictures";  Ziel=Join-Path $ZielBasisPfad "Pictures"   }
    [PSCustomObject]@{ Name="Musik";     Quelle="\\$AlterPcIP\C_Umzug\Users\$AlterBenutzer\Music";     Ziel=Join-Path $ZielBasisPfad "Music"      }
    [PSCustomObject]@{ Name="Videos";    Quelle="\\$AlterPcIP\C_Umzug\Users\$AlterBenutzer\Videos";    Ziel=Join-Path $ZielBasisPfad "Videos"     }
)

$auswahl = $quellen | Out-GridView -Title "Ordner auswaehlen (STRG+Klick = mehrere, dann OK)" -PassThru

if (-not $auswahl) {
    Write-Host "Keine Auswahl getroffen. Abbruch." -ForegroundColor Red
    exit
}

# 3. Kopieren
Write-Host "`n[3/3] Kopiere Dateien..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "C:\Migration_Inventar" -Force | Out-Null
$protokoll = @()

foreach ($o in $auswahl) {
    Write-Host "  $($o.Name)..." -NoNewline
    New-Item -ItemType Directory -Path $o.Ziel -Force | Out-Null
    robocopy $o.Quelle $o.Ziel /E /R:2 /W:3 /NP /LOG+:"C:\Migration_Inventar\robocopy_$($o.Name).log" | Out-Null
    $ok = $LASTEXITCODE -lt 8
    Write-Host $(if ($ok) { " OK" } else { " FEHLER (Code $LASTEXITCODE)" }) -ForegroundColor $(if ($ok) { "Green" } else { "Red" })
    $protokoll += [PSCustomObject]@{ Name=$o.Name; Quelle=$o.Quelle; Status=if($ok){"OK"}else{"FEHLER"} }
}

# Verbindungen trennen
$shares | ForEach-Object { net use "\\$AlterPcIP\$_" /delete 2>&1 | Out-Null }

$protokoll | Export-Csv "C:\Migration_Inventar\protokoll_direkt.csv" -Encoding UTF8 -NoTypeInformation

Write-Host "`n=== Fertig! ===" -ForegroundColor Green
$protokoll | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Status)" -ForegroundColor $(if ($_.Status -eq "OK") { "Green" } else { "Red" })
}
Write-Host "Logs: C:\Migration_Inventar\"
