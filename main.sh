#!/usr/bin/env bash

#
# Backup einer Contao 4 Installation (Dateien und Datenbank)
#

# - - - - - - - - - -
# Start Konfiguration
# - - - - - - - - - -


# Pfade zu den benötigten Programmen
# Hier ggf. den vollständigen Pfad angeben

PHP_CLI=php
MYSQLDUMP=mysqldump
TAR=tar
# Bei manchen Providern ist tar nicht verfügbar.
# Bei allinkl z.B. muss als Alternative ptar verwendet werden!
#TAR=ptar


# Optionale Parameter

# Format des Zeitstempels, der als Bestandteil der Backupdateien verwendet werden soll.
# Standardwert (wenn nicht gesetzt) ist '%Y-%m-%d'.

#BACKUP_TIMESTAMP_FORMAT='%Y-%m-%d_%H_%M_%S'

# Dito für das Löschen der alten Backups (siehe PURGE_AFTER_DAYS weiter unten).
# Muss "natürlich" zum BACKUP_TIMESTAMP_FORMAT passen!

#PURGE_TIMESTAMP_FORMAT='%Y-%m-%d'

# Betriebssystem. Wird benötigt um beim `date`-Aufruf die Parameter geeignet zu setzen.
## Wird automatisch bestimmt wenn der Befehl `uname` zur Verfügung steht, was nicht immer
## der Fall ist -- siehe https://github.com/fiedsch/contao-4-backup-script/issues/6. In diesem
## Fall muss hier die Variable OS gesetzt werden, die ansonsten undefiniert bleiben kann.

#OS='Linux'
#OS='FreeBSD'
#OS='Darwin'


# Verbosity (Debug)
DEBUG=0
# DEBUG=1

# Beim Aufruf über ein PHP Skript (z.B. all-inkl cron job) bestimmte Ausgaben nicht anzeigen (see #13)
HIDE_ON_WEB_CALL=0
# HIDE_ON_WEB_CALL=1

# Funktionen, die vom Provider entfernt wurden
DISABLED_FUNCTIONS=''
# Bsp. für all-inkl
# DISABLED_FUNCTIONS='ls'


# Zielverzeichnis = Wo sollen die erzeugten Backups abgelegt werden.
# Auf einem Produktivsystem ist ein öffentlich zugängliches Verzeichnis
# keine tolle Idee ...

TARGET_DIR=/some/dir/outside/the/webroot


# Basisname der erzeugten Backupdateien
# (z.B. Projektname oder Domain).

DUMP_NAME=myprojekt


# Name des Contao Installationsverzeichnises.
#
# Achtung: hier wird das Verzeichnis angegeben, in Contao installiert wurde.
# Das ist das Verzeichnis, in dem die composer.json der Installation liegt.
# NICHT gemeint ist das Unterverzeichnis web/, auf das die Domain gesetzt wurde
# (siehe dazu WEB_ROOT weiter unten)!

CONTAO_DIR=/path/to/contao/installation/directory


# Web-Root = der öffentlich erreichbare Unterordner.
# web (oder public ab Contao 4.12)
# siehe auch https://docs.contao.org/manual/de/installation/systemvoraussetzungen/#hosting-konfiguration
WEB_ROOT=web


# Soll das files Verzeichnis auch gesichert werden?
#
# Wenn das files/ Verzeichnis sehr groß ist, ist es evtl. sinnvoll,
# hier das Backup auszuschalten und dieses Verzeichnis mit einem anderen
# Mechanismus zu sichern (z.B. via rsync).

BACKUP_CONTAO_FILES=1
#BACKUP_CONTAO_FILES=0


# Zusätzlich zum Standard (composer.{json,lock}, app/, ..., src/) zu
# sichernde Verzeichnisse und Dateien.
# Pfadangabe jeweils relativ zum CONTAO_DIR.
# Bsp.:
# * das share/ Verzeichnis mit der/den Sitemaps
# * Unterverzeichnis(se) von system/modules/ bei manuell installierten Contao 3 Erweiterungen

#BACKUP_USER_DIRS="${WEB_ROOT}/share/ system/modules/myextension/"
BACKUP_USER_DIRS=''


# Wie BACKUP_USER_DIRS, nur für einzelne Dateien.
# Kann für Dateien aus web/, die nicht zwingend existieren müssen
# (wie z.B. web/robots.txt web/manifest.json), die Zugangsdaten für die app_dev.php (.env),
# oder beliebige andere Dateien verwendet werden. Angabe jeweils relativ zum CONTAO_DIR.

#BACKUP_USER_FILES=".env ${WEB_ROOT}/robots.txt ${WEB_ROOT}/manifest.json system/config/dcaconfig.php"
BACKUP_USER_FILES=''


# Verzeichnis in dem das Haupt-Skript (c4-backup.sh) gespeichert ist.
# Wird u.A. für absolute Pfade in cron jobs benötigt.

SCRIPT_DIR=/dir/where/the/main/backup_script/is/located


# Optionen für mysqldump (Datenbankdump)
# siehe 'man mysqldump'

#DBOPTIONS=''
DBOPTIONS='--hex-blob --add-drop-table --comments --dump-date --no-tablespaces'


# Nicht zu sichernde Datenbanktabellen
# Eine durch Leerzeichen getrennte Liste, die aber auch leer sein darf.
# Von diesen Tabellen wird nur die Tabellenstruktur, aber keine Daten gesichert.
# Vgl. auch https://docs.contao.org/manual/de/cli/datenbank-backups/#konfigurationsmoeglichkeiten

#SKIP_THESE_TABLES=''
SKIP_THESE_TABLES='tl_crawl_queue tl_log tl_search tl_search_index tl_search_term tl_undo tl_version'


# Alte Backups nach x Tagen periodisch löschen?
# Auf 0 setzen um das Löschen zu deaktivieren.

#PURGE_AFTER_DAYS=0
PURGE_AFTER_DAYS=14


# - - - - - - - - - -
# Ende Konfiguration
# - - - - - - - - - -


# Das Haupt-Skript aufrufen, das die eigentliche Backup-Logik enthält.

source ${SCRIPT_DIR}/c4-backup.sh

## EOF ##
