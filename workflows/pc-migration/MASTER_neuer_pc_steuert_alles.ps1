# ============================================================
# MASTER-SCRIPT: Nur auf dem NEUEN PC (Win 11) ausfuehren
# Claude Code Desktop Terminal -> Als Administrator starten
#
# Dieser Script steuert alles automatisch:
#   1. Verbindet sich mit dem alten PC per PSRemoting
#   2. Richtet Shares und SMB ein (Fernsteuerung)
#   3. Scannt alle Programme und Ordner remote
#   4. Zeigt interaktive Auswahl (lokal auf neuem PC)
#   5. Fuehrt Migration durch (winget + robocopy)
# ============================================================

param(
    [string]$AlterPcIP      = "",     # IP des alten PCs z.B. "192.168.0.10"
    [string]$AlterPcUser    = "",     # Benutzername auf dem alten PC
    [string]$AusgabePfad    = "C:\Migration_Inventar",
    [string]$ZielBasisPfad  = "C:\Users\$env:USERNAME"
)

# ---- Verbindungsparameter abfragen falls nicht angegeben ----
if (-not $AlterPcIP)   { $AlterPcIP   = Read-Host "IP des alten PCs (z.B. 192.168.0.10)" }
if (-not $AlterPcUser) { $AlterPcUser = Read-Host "Benutzername auf altem PC (z.B. MaxMuster)" }
$AlterPcPw = Read-Host "Passwort des alten PCs" -AsSecureString
$credentials = New-Object System.Management.Automation.PSCredential($AlterPcUser, $AlterPcPw)

New-Item -ItemType Directory -Path $AusgabePfad -Force | Out-Null

# ============================================================
# SCHRITT 1: PSRemoting auf altem PC aktivieren (via WinRM)
# ============================================================
Write-Host "`n[1/4] Verbinde mit altem PC und richte Fernsteuerung ein..." -ForegroundColor Cyan

# WinRM auf neuem PC fuer TrustedHosts konfigurieren
$aktuell = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
if ($aktuell -notlike "*$AlterPcIP*") {
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$aktuell,$AlterPcIP" -Force
}

# PSRemoting auf dem ALTEN PC per WinRM aktivieren
# Dazu brauchen wir zuerst eine direkte WinRM-Verbindung
# (Der Benutzer muss WinRM auf dem alten PC einmalig per Hand aktiviert haben)
Write-Host "  Pruefe Verbindung zu $AlterPcIP..."
$ping = Test-Connection -ComputerName $AlterPcIP -Count 1 -Quiet
if (-not $ping) {
    Write-Host "FEHLER: Kein Ping zu $AlterPcIP moeglich." -ForegroundColor Red
    Write-Host "Sicherstellen: Beide PCs im selben Netzwerk / LAN-Kabel verbunden."
    exit 1
}
Write-Host "  Ping OK." -ForegroundColor Green

# Remote-Session oeffnen
try {
    $session = New-PSSession -ComputerName $AlterPcIP -Credential $credentials -ErrorAction Stop
    Write-Host "  PSRemoting-Verbindung hergestellt." -ForegroundColor Green
} catch {
    Write-Host "PSRemoting-Verbindung fehlgeschlagen: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "EINMALIGE VORBEREITUNG auf dem ALTEN PC (als Admin):" -ForegroundColor Yellow
    Write-Host "  powershell -Command `"Enable-PSRemoting -Force; Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force`""
    Write-Host ""
    Write-Host "Danach dieses Script erneut starten."
    exit 1
}

# ============================================================
# SCHRITT 2: Shares + SMB + Scan auf altem PC ausfuehren
# ============================================================
Write-Host "`n[2/4] Richte Shares ein und scanne Inventar auf altem PC..." -ForegroundColor Cyan

$inventar = Invoke-Command -Session $session -ScriptBlock {
    # Firewall und SMB
    Enable-NetFirewallRule -DisplayGroup "Datei- und Druckerfreigabe" -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -DisplayGroup "Netzwerkerkennung" -ErrorAction SilentlyContinue
    Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force -ErrorAction SilentlyContinue

    # Netzwerkprofil Privat
    Get-NetConnectionProfile | Where-Object {$_.NetworkCategory -ne "Private"} | ForEach-Object {
        Set-NetConnectionProfile -Name $_.Name -NetworkCategory Private
    }

    # Laufwerke freigeben
    Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Root -match '^[A-Z]:\\$'} | ForEach-Object {
        $sn = $_.Name + "_Umzug"
        if (-not (Get-SmbShare -Name $sn -ErrorAction SilentlyContinue)) {
            New-SmbShare -Name $sn -Path $_.Root -FullAccess "Everyone" | Out-Null
        }
    }

    # Programme scannen
    $regPfade = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $programme = @()
    foreach ($p in $regPfade) {
        Get-ItemProperty $p -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        ForEach-Object {
            $programme += [PSCustomObject]@{
                Name       = $_.DisplayName
                Version    = $_.DisplayVersion
                Publisher  = $_.Publisher
                Groesse_MB = if ($_.EstimatedSize) { [math]::Round($_.EstimatedSize/1024,1) } else { $null }
                WingetID   = $null
            }
        }
    }
    $programme = $programme | Sort-Object Name -Unique

    # Winget-IDs
    try {
        $wl = winget list --accept-source-agreements 2>$null
        $wids = @{}
        $wl | Select-Object -Skip 3 | ForEach-Object {
            if ($_ -match '^(.+?)\s{2,}(.+?)\s{2,}([\d\.]+)\s{2,}(\S+)') {
                $wids[$Matches[1].Trim()] = $Matches[4].Trim()
            }
        }
        $programme | ForEach-Object { if ($wids[$_.Name]) { $_.WingetID = $wids[$_.Name] } }
    } catch {}

    # Benutzer-Ordner
    $ordner = @(
        [PSCustomObject]@{ Name="Desktop";   Pfad=$env:USERPROFILE+"\Desktop";   Groesse_MB=$null }
        [PSCustomObject]@{ Name="Dokumente"; Pfad=$env:USERPROFILE+"\Documents"; Groesse_MB=$null }
        [PSCustomObject]@{ Name="Downloads"; Pfad=$env:USERPROFILE+"\Downloads"; Groesse_MB=$null }
        [PSCustomObject]@{ Name="Bilder";    Pfad=$env:USERPROFILE+"\Pictures";  Groesse_MB=$null }
        [PSCustomObject]@{ Name="Musik";     Pfad=$env:USERPROFILE+"\Music";     Groesse_MB=$null }
        [PSCustomObject]@{ Name="Videos";    Pfad=$env:USERPROFILE+"\Videos";    Groesse_MB=$null }
    )
    foreach ($o in $ordner) {
        if (Test-Path $o.Pfad) {
            $s = (Get-ChildItem $o.Pfad -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $o.Groesse_MB = [math]::Round($s/1MB,1)
        }
    }

    return [PSCustomObject]@{
        ErstelltAm     = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Hostname       = $env:COMPUTERNAME
        WindowsVersion = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        Programme      = $programme
        Ordner         = $ordner
    }
}

Write-Host "  Alter PC: $($inventar.Hostname) | $($inventar.WindowsVersion)" -ForegroundColor Green
Write-Host "  $($inventar.Programme.Count) Programme gefunden."

# Inventar lokal speichern
$inventar | ConvertTo-Json -Depth 5 | Out-File "$AusgabePfad\inventar.json" -Encoding UTF8

# ============================================================
# SCHRITT 3: Interaktive Auswahl (lokal auf neuem PC)
# ============================================================
Write-Host "`n[3/4] Auswahl-Fenster werden geoeffnet..." -ForegroundColor Cyan
Write-Host "  STRG+Klick = mehrere auswaehlen, dann OK klicken"

$ausgewaehlteProgramme = $inventar.Programme |
    Select-Object Name, Version, Publisher, Groesse_MB, WingetID |
    Out-GridView -Title "PROGRAMME auswaehlen (STRG+Klick, dann OK)" -PassThru

$ausgewaehlteOrdner = $inventar.Ordner |
    Select-Object Name, Pfad, Groesse_MB |
    Out-GridView -Title "ORDNER auswaehlen (STRG+Klick, dann OK)" -PassThru

Write-Host "  $($ausgewaehlteProgramme.Count) Programme | $($ausgewaehlteOrdner.Count) Ordner ausgewaehlt."

# ============================================================
# SCHRITT 4: Migration durchfuehren
# ============================================================
Write-Host "`n[4/4] Migration startet..." -ForegroundColor Cyan

$protokoll = @()
$ordnerMap = @{ "Desktop"="Desktop"; "Dokumente"="Documents"; "Downloads"="Downloads"; "Bilder"="Pictures"; "Musik"="Music"; "Videos"="Videos" }

# 4a. Programme via winget auf neuem PC installieren
Write-Host "`n  Programme installieren:" -ForegroundColor Yellow
foreach ($prog in $ausgewaehlteProgramme) {
    if ($prog.WingetID) {
        Write-Host "    $($prog.Name)..." -NoNewline
        winget install --id $prog.WingetID --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        $ok = $LASTEXITCODE -eq 0
        Write-Host $(if ($ok) { " OK" } else { " FEHLER" }) -ForegroundColor $(if ($ok) { "Green" } else { "Red" })
        $protokoll += [PSCustomObject]@{ Typ="Programm"; Name=$prog.Name; Methode="winget"; Status=if($ok){"OK"}else{"FEHLER"} }
    } else {
        Write-Host "    $($prog.Name) -> manuell installieren" -ForegroundColor DarkYellow
        $protokoll += [PSCustomObject]@{ Typ="Programm"; Name=$prog.Name; Methode="Manuell"; Status="AUSSTEHEND" }
    }
}

# 4b. Ordner via robocopy ueber Netzwerk-Share kopieren
Write-Host "`n  Dateien kopieren:" -ForegroundColor Yellow
foreach ($ordner in $ausgewaehlteOrdner) {
    $laufwerk = (Split-Path $ordner.Pfad -Qualifier).TrimEnd(':')
    $share    = "${laufwerk}_Umzug"
    $relPfad  = $ordner.Pfad -replace [regex]::Escape((Split-Path $ordner.Pfad -Qualifier) + "\"), ""
    $quelle   = "\\$AlterPcIP\$share\$relPfad"
    $zielName = if ($ordnerMap[$ordner.Name]) { $ordnerMap[$ordner.Name] } else { $ordner.Name }
    $ziel     = Join-Path $ZielBasisPfad $zielName
    $log      = "$AusgabePfad\robocopy_$($ordner.Name).log"

    Write-Host "    $($ordner.Name) ($($ordner.Groesse_MB) MB)..." -NoNewline
    robocopy $quelle $ziel /E /COPYALL /R:2 /W:3 /NP /LOG+:$log | Out-Null
    $ok = $LASTEXITCODE -lt 8
    Write-Host $(if ($ok) { " OK" } else { " FEHLER" }) -ForegroundColor $(if ($ok) { "Green" } else { "Red" })
    $protokoll += [PSCustomObject]@{ Typ="Ordner"; Name=$ordner.Name; Methode="robocopy"; Status=if($ok){"OK"}else{"FEHLER"} }
}

# Session schliessen
Remove-PSSession $session

# Protokoll speichern
$protokoll | Export-Csv "$AusgabePfad\protokoll.csv" -Encoding UTF8 -NoTypeInformation

# ============================================================
# Zusammenfassung
# ============================================================
Write-Host "`n=== Migration abgeschlossen! ===" -ForegroundColor Green
$protokoll | Group-Object Status | ForEach-Object {
    $farbe = switch ($_.Name) { "OK" { "Green" } "AUSSTEHEND" { "Yellow" } default { "Red" } }
    Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor $farbe
}

$ausstehend = $protokoll | Where-Object { $_.Status -eq "AUSSTEHEND" }
if ($ausstehend) {
    Write-Host "`nManuell installieren:" -ForegroundColor Yellow
    $ausstehend | ForEach-Object { Write-Host "  - $($_.Name)" }
}
Write-Host "`nProtokoll: $AusgabePfad\protokoll.csv"
