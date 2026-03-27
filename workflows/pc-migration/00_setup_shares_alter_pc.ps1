# ============================================================
# SETUP: Auf dem ALTEN PC (Windows 10) ausfuehren
# Aktiviert Netzwerk-Freigaben fuer den PC-Umzug
# Als Administrator starten!
# ============================================================

Write-Host "=== Netzwerk-Freigaben einrichten ===" -ForegroundColor Cyan

# Firewall-Regeln aktivieren
Enable-NetFirewallRule -DisplayGroup "Datei- und Druckerfreigabe"
Enable-NetFirewallRule -DisplayGroup "Netzwerkerkennung"

# SMB2 aktivieren
Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force

# Netzwerkprofil auf Privat setzen
Get-NetConnectionProfile | Where-Object {$_.NetworkCategory -ne "Private"} | ForEach-Object {
    Set-NetConnectionProfile -Name $_.Name -NetworkCategory Private
}

# Alle lokalen Laufwerke freigeben
Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Root -match '^[A-Z]:\\$'} | ForEach-Object {
    $name = $_.Name + "_Umzug"
    $path = $_.Root
    if (-not (Get-SmbShare -Name $name -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name $name -Path $path -FullAccess "Everyone"
        Write-Host "Freigegeben: $name -> $path" -ForegroundColor Green
    } else {
        Write-Host "Bereits freigegeben: $name" -ForegroundColor Gray
    }
}

# Verbindungsinfos ausgeben
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.*"
} | Select-Object -First 1).IPAddress

Write-Host "`n=== Verbindungsinfo fuer neuen PC ===" -ForegroundColor Cyan
Write-Host "IP:      $ip"
Write-Host "Zugriff: \\$ip"
Write-Host "`nDiese IP beim naechsten Schritt als -AlterPcIP angeben!"
