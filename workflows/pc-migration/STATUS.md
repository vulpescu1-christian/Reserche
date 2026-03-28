# PC-Umzug Status

## Verbindungsdaten
- Alter PC (Win 10): IP `192.168.1.37`, User `user`, Passwort `Kinderschutz`
- Neuer PC (Win 11): Claude Code Desktop

## Erledigte Schritte
- [x] Netzwerk-Shares auf altem PC eingerichtet (SMB, Firewall)
- [x] PSRemoting auf altem PC aktiviert (`EINMALIG_alter_pc_psremoting.ps1`)
- [x] PSRemoting + WinRM auf neuem PC aktiviert (`Enable-PSRemoting -Force`)
- [x] TrustedHosts auf neuem PC gesetzt (`*`)
- [x] Migration-Scripts auf GitHub gepusht

## Naechster Schritt
Auf dem NEUEN PC (Win 11) als Administrator:
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Migration\master.ps1" -AlterPcIP "192.168.1.37" -AlterPcUser "user"
```
Passwort: Kinderschutz

## Scripts (GitHub)
Branch: `claude/windows-10-to-11-migration-7IdIR`
- `MASTER_neuer_pc_steuert_alles.ps1` - Hauptscript (neuer PC)
- `EINMALIG_alter_pc_psremoting.ps1` - PSRemoting (alter PC, einmalig)
