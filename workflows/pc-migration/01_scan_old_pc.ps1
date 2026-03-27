# ============================================================
# SCHRITT 1: Auf dem ALTEN PC (Windows 10) ausfuehren
# Scannt alle installierten Programme und Benutzer-Ordner
# Als Administrator starten!
# ============================================================

param(
    [string]$AusgabePfad = "C:\Migration_Inventar"
)

Write-Host "=== PC-Umzug: Inventar wird erstellt ===" -ForegroundColor Cyan
Write-Host "Ausgabepfad: $AusgabePfad"
New-Item -ItemType Directory -Path $AusgabePfad -Force | Out-Null

# ------------------------------------------------------------
# 1. Installierte Programme aus Registry scannen
# ------------------------------------------------------------
Write-Host "`n[1/3] Scanne installierte Programme..." -ForegroundColor Yellow

$regPfade = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$programme = @()
foreach ($pfad in $regPfade) {
    Get-ItemProperty $pfad -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and $_.DisplayName.Trim() -ne "" } |
    ForEach-Object {
        $programme += [PSCustomObject]@{
            Name         = $_.DisplayName
            Version      = $_.DisplayVersion
            Publisher    = $_.Publisher
            InstallDatum = $_.InstallDate
            InstallPfad  = $_.InstallLocation
            Groesse_MB   = if ($_.EstimatedSize) { [math]::Round($_.EstimatedSize / 1024, 1) } else { $null }
            WingetID     = $null
            Ausgewaehlt  = $true
        }
    }
}

$programme = $programme | Sort-Object Name -Unique
Write-Host "   $($programme.Count) Programme gefunden."

# ------------------------------------------------------------
# 2. Winget-IDs ergaenzen (falls vorhanden)
# ------------------------------------------------------------
Write-Host "[2/3] Pruefe winget..." -ForegroundColor Yellow

try {
    $wingetAusgabe = winget list --accept-source-agreements 2>$null
    if ($wingetAusgabe) {
        $wingetIds = @{}
        $wingetAusgabe | Select-Object -Skip 3 | ForEach-Object {
            if ($_ -match '^(.+?)\s{2,}(.+?)\s{2,}([\d\.]+)\s{2,}(\S+)') {
                $wingetIds[$Matches[1].Trim()] = $Matches[4].Trim()
            }
        }
        $programme | ForEach-Object {
            if ($wingetIds.ContainsKey($_.Name)) {
                $_.WingetID = $wingetIds[$_.Name]
            }
        }
        Write-Host "   Winget-IDs zugeordnet."
    }
} catch {
    Write-Host "   Winget nicht verfuegbar - wird uebersprungen." -ForegroundColor Gray
}

# ------------------------------------------------------------
# 3. Benutzer-Ordner inventarisieren
# ------------------------------------------------------------
Write-Host "[3/3] Scanne Benutzer-Ordner..." -ForegroundColor Yellow

$benutzerOrdner = @(
    [PSCustomObject]@{ Name="Desktop";   Pfad=$env:USERPROFILE+"\Desktop";   Groesse_MB=$null; Ausgewaehlt=$true  }
    [PSCustomObject]@{ Name="Dokumente"; Pfad=$env:USERPROFILE+"\Documents"; Groesse_MB=$null; Ausgewaehlt=$true  }
    [PSCustomObject]@{ Name="Downloads"; Pfad=$env:USERPROFILE+"\Downloads"; Groesse_MB=$null; Ausgewaehlt=$false }
    [PSCustomObject]@{ Name="Bilder";    Pfad=$env:USERPROFILE+"\Pictures";  Groesse_MB=$null; Ausgewaehlt=$true  }
    [PSCustomObject]@{ Name="Musik";     Pfad=$env:USERPROFILE+"\Music";     Groesse_MB=$null; Ausgewaehlt=$true  }
    [PSCustomObject]@{ Name="Videos";    Pfad=$env:USERPROFILE+"\Videos";    Groesse_MB=$null; Ausgewaehlt=$true  }
)

foreach ($ordner in $benutzerOrdner) {
    if (Test-Path $ordner.Pfad) {
        $groesse = (Get-ChildItem $ordner.Pfad -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $ordner.Groesse_MB = [math]::Round($groesse / 1MB, 1)
        Write-Host "   $($ordner.Name): $($ordner.Groesse_MB) MB"
    }
}

# ------------------------------------------------------------
# Inventar als JSON speichern (auch im Share zugaenglich)
# ------------------------------------------------------------
$inventar = [PSCustomObject]@{
    ErstelltAm     = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Hostname       = $env:COMPUTERNAME
    Benutzer       = $env:USERNAME
    WindowsVersion = (Get-WmiObject -Class Win32_OperatingSystem).Caption
    Programme      = $programme
    Ordner         = $benutzerOrdner
}

$jsonPfad = Join-Path $AusgabePfad "inventar.json"
$inventar | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPfad -Encoding UTF8

Write-Host "`n=== Fertig! ===" -ForegroundColor Green
Write-Host "Inventar gespeichert: $jsonPfad"
Write-Host "Naechster Schritt: 02_auswahl_treffen.ps1 auf dem NEUEN PC ausfuehren."
Write-Host "Inventar-Pfad im Netzwerk: \\$((Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike '*Loopback*' -and $_.IPAddress -notlike '169.*'} | Select-Object -First 1).IPAddress)\C_Umzug\Migration_Inventar\inventar.json"
