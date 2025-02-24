# Backup Script für Contao Installationen (Contao 4+)

## Was macht es

Erstellt ein Backup einer Contao Installation. Erzeugt werden drei Dateien:

* Datenbankdump
* Sicherung der für eine Wiederherstellung benötigten Dateien
* Sicherung des `files/` Verzeichnisses

## Requirements

* bash
* PHP-Cli (passend zur PHP-Version unter der Contao läuft)
* `mysqldump`



## Installation/Verwendung

* Anpassen der Datei `main.sh` an den eigenen Bedarf (siehe Kommentare in der Datei)
* Aufruf der `main.sh` manuell oder periodisch in einem cron-job

```bash
# Projektverzeichnis erstellen (z.B.)
mkdir backup/contao
cd backup/contao
git clone https://github.com/fiedsch/contao-4-backup-script
cp contao-4-backup-script/main.sh ./meinbackup.sh
# meinbackup.sh (oder wie auch immer Du die Datei für Dich passend genannt hast)
# bearbeiten und die zur Contao Installation passenden Parameter setzen.
# Dann meinbackup.sh in einen cron job eintragen.
```



## Spezielle Anpassungen (abhängig vom Provider)

Manche Provider stellen nicht alle im Skript benötigten Befehle bereit (sperren den Zugriff).
Über spezielle Konfigurationsoptionen soll versucht werden, dies zu berücksichtigen.


### All-Inkl

In der `main.sh`
* `TAR` auf den Wert `ptar` setzen
* `OS` auf den Wert `Linux` setzen
* `PURGE_AFTER_DAYS` auf `0` setzen (@mlwebworker: weil der Befehl zum Löschen nicht freigegeben ist. Die Löschung kann dann über Tools → Webspacebereinigung automatisiert werden)
* `DISABLED_FUNCTIONS` auf `'ls'` setzen (ggf. die Liste um weitere deaktivierte Befehle ergänzen; kommaseparierte Liste)

### Mittwald

@zonky2: In der `main.sh`
 * `OS` auf den Wert `Linux` setzen
 
@codesache: 
 * `mysql` muss u.U. erst über den Softwaremanager installiert werden (Paket GROW)


### Andere Provider

Feedback zu weiteren Providern, bei denen es noch nicht gelöste Probleme gibt gerne
als Issue in diesem Repository mitteilen - Danke!


## Restore

* Backup-Dateien in das entsprechende Verzeichnis auf dem Server entpacken
* Datenbankdump einspielen (Datenbank ggf. neu anlegen)
* `composer install`
* Aufruf des Contao Installtools im Browser


## Was noch fehlt

* Liste der gesicherten Dateien auf "ist alles benötigte dabei" prüfen (möglichst viele
  Spezialfälle berücksichtigen; Danke für Feedback/"Issues" falls ihr etwas findet!)
* Fehlerprüfungen und ggf. -meldungen
