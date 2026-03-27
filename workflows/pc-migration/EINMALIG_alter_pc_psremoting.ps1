# ============================================================
# EINMALIG auf dem ALTEN PC (Win 10) ausfuehren!
# Aktiviert PSRemoting damit der neue PC fernsteuern kann
# Als Administrator starten!
# ============================================================

Write-Host "=== PSRemoting auf altem PC aktivieren ===" -ForegroundColor Cyan

# PSRemoting aktivieren
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Alle Hosts als vertrauenswuerdig markieren (fuer LAN-Verbindung)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# WinRM-Dienst starten und auf automatisch setzen
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# Firewall-Regel fuer WinRM
Enable-NetFirewallRule -DisplayName "Windows-Remoteverwaltung (HTTP eingehend)" -ErrorAction SilentlyContinue
New-NetFirewallRule -Name "WinRM-HTTP" -DisplayName "WinRM HTTP (PC-Umzug)" `
    -Enabled True -Direction Inbound -Protocol TCP -LocalPort 5985 `
    -Action Allow -ErrorAction SilentlyContinue | Out-Null

# Netzwerkprofil auf Privat setzen
Get-NetConnectionProfile | Where-Object {$_.NetworkCategory -ne "Private"} | ForEach-Object {
    Set-NetConnectionProfile -Name $_.Name -NetworkCategory Private
}

# IP-Adresse anzeigen
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.*"
} | Select-Object -First 1).IPAddress

Write-Host "`n=== Fertig! ===" -ForegroundColor Green
Write-Host "IP dieses PCs: $ip"
Write-Host ""
Write-Host "Auf dem NEUEN PC jetzt ausfuehren:" -ForegroundColor Yellow
Write-Host "  powershell -ExecutionPolicy Bypass -File MASTER_neuer_pc_steuert_alles.ps1 -AlterPcIP $ip"
