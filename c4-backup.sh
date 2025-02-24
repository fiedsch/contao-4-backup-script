#!/bin/bash

echo "starte Backup ${DUMP_NAME}"

# shellcheck disable=SC2086

# Sind die benötigten Variablen gesetzt?

if [ -z "$PHP_CLI" ]
then
  echo "Fehler in $0: Variable PHP_CLI ist nicht gesetzt"
  return
fi

if [ -z "$MYSQLDUMP" ]
then
  echo "Fehler in $0: Variable MYSQLDUMP ist nicht gesetzt"
  return
fi

if [ -z "$TAR" ]
then
  echo "Fehler in $0: Variable TAR ist nicht gesetzt"
  return
fi

# BC if DEBUG is not set
if [ -z "$DEBUG" ]
then
  DEBUG=0
fi

# BC if HIDE_ON_WEB_CALL is not set
if [ -z "$HIDE_ON_WEB_CALL" ]
then
  HIDE_ON_WEB_CALL=1
fi

# BC if DISABLED_FUNCTIONS is not set
if [ -z "$DISABLED_FUNCTIONS" ]
then
  DISABLED_FUNCTIONS=''
fi

# Prüfen, ob eine Funktion in der Liste DISABLED_FUNCTIONS enthalten ist
function is_disabled() {
    SEARCH=$1
    for x in $DISABLED_FUNCTIONS
    do
        if [ "$x" = "$SEARCH" ]; then
            return 0
        fi
    done
    return 1
}


# Sind die benötigten Programme vorhanden? (für hartkodierte Programmaufrufe wie gzip oder uname)

function assert_command() {
  # echo "TESTE '$1'"
  hash "$1" 2>/dev/null
  RESULT=$?
  #echo "result fuer '$1' ist '$RESULT'"
  if [ ${RESULT} -gt 0 ]
  then
    echo "Fehler in $0: '$1' nicht verfügbar $2"
    return 1
  fi
  return 0
}

assert_command 'gzip' || return

if [ -z "${OS}" ]
  then assert_command 'uname' "(Behebung: 'OS' setzen)" || return
fi


# Variablen bereinigen

# Slash am Ende entfernen (falls vorhanden -- ansonsten no-op)

CONTAO_DIR=${CONTAO_DIR%/}
WEB_ROOT=${WEB_ROOT%/}
TARGET_DIR=${TARGET_DIR%/}
SCRIPT_DIR=${SCRIPT_DIR%/}

# Slashes durch - ersetzen
# (und führendes - und - am Ende entfernen)

DUMP_NAME=$(echo "${DUMP_NAME}" | tr '/' '-')
DUMP_NAME=${DUMP_NAME#-}
DUMP_NAME=${DUMP_NAME##-}


# Checks: Existieren die angegebenen Verzeichnisse?

if [ ! -d "${SCRIPT_DIR}" ]
then
    echo "Fehler in $0: SCRIPT_DIR: Verzeichnis ${SCRIPT_DIR} existiert nicht"
    return
fi

if [ ! -d "${CONTAO_DIR}" ]
then
    echo "Fehler in $0: CONTAO_DIR: Verzeichnis ${CONTAO_DIR} existiert nicht"
    return
fi

if [ ! -d "${TARGET_DIR}" ]
then
    echo "Fehler in $0: TARGET_DIR: Verzeichnis ${TARGET_DIR} existiert nicht"
    return
fi


# Aktuelles Datum als Teil des Dateinamens der Basckupdateien.
# Kann mit der Variablen BACKUP_TIMESTAMP_FORMAT konfiguriert werden.
# Falls diese nicht gesetzt ist, wird ein Standard verwendet.

if [ -z "${BACKUP_TIMESTAMP_FORMAT}" ]
then
  BACKUP_TIMESTAMP_FORMAT='%Y-%m-%d'
fi

NOW=$(date +"${BACKUP_TIMESTAMP_FORMAT}")


# Backup des files/ Verzeichnisses erstellen?

if [ ${BACKUP_CONTAO_FILES} -gt 0 ]
then
    ( cd "${CONTAO_DIR}" && ${TAR} cf "${TARGET_DIR}/${DUMP_NAME}_${NOW}.files.tar" files && gzip --force "${TARGET_DIR}/${DUMP_NAME}_${NOW}.files.tar" )
else
    ( echo "Dateisicherung übersprungen, da BACKUP_CONTAO_FILES=${BACKUP_CONTAO_FILES} in $0" > "${TARGET_DIR}/${DUMP_NAME}_${NOW}.files.txt" )
fi


# Backup "der anderen" Dateien.
# (a.1) Dateien, die in einer Standard Managed-Edition vorhanden sind

read -r -d '' FILE_LIST <<- EOF
    composer.json composer.lock
    system/config/localconfig.php
    templates/
    ${WEB_ROOT}/.htaccess
EOF

# (a.2) app/ bzw. ab Contao 4.8 config/ und contao/

for d in app config contao
do
    if [ -d "${CONTAO_DIR}/${d}" ]
    then
        FILE_LIST="${FILE_LIST} ${d}/"
    fi
done

# (b) ggf. vorhandenes Verzeichnis src/ (anwendungsspezifische Erweiterungen)

if [ -d "${CONTAO_DIR}/src" ]
then
    FILE_LIST="${FILE_LIST} src/"
fi

# (c) Benutzerdefinierte Verzeichnisse (können in der Konfiguration angegeben werden)

if [ -n "${BACKUP_USER_DIRS}" ]
then
    for d in ${BACKUP_USER_DIRS}
    do
        if [ -d "${CONTAO_DIR}/$d" ]
        then
            FILE_LIST="${FILE_LIST} ${d}"
        fi
    done
fi

# (d) Wie (c), nur für einzelne Dateien

if [ -n "${BACKUP_USER_FILES}" ]
then
    for f in ${BACKUP_USER_FILES}
    do
        if [ -e "${CONTAO_DIR}/${f}" ]
        then
            FILE_LIST="${FILE_LIST} ${f}"
        fi
    done
fi


#  FILE_LIST sichern

( cd "${CONTAO_DIR}" && ${TAR} cf "${TARGET_DIR}/${DUMP_NAME}_${NOW}.tar" ${FILE_LIST} && gzip --force "${TARGET_DIR}/${DUMP_NAME}_${NOW}.tar" )


# Datenbank Verbindungsdaten bestimmen

# Dazu die Datenbank Verbindungsdaten aus der Installation holen.
# Die Ausgabe sieht z.B. so aus:
#
# --------------- -------
#   Parameter       Value
#  --------------- -------
#   database_user   jdbc
#  --------------- -------
#
# Wir benötigen "das zweite Wort der vierten Zeile" (den "Value")

function get_db_param() {
    PARAMETER=$1
    ${PHP_CLI} "${CONTAO_DIR}/vendor/bin/contao-console" debug:container --parameter=${PARAMETER} 2>/dev/null \
      | sed -n 4p \
      | sed -e's/^ *//' \
      | cut -d' ' -f2- \
      | sed -e's/^ *//' | sed -e's/ *$//'
    return 0
}

function get_db_url_from_env() {
    if [ -f "${CONTAO_DIR}/bin/console" ]
    then
       COMMAND="${PHP_CLI} "${CONTAO_DIR}/bin/console" debug:dotenv"
    else
      if [ -f "${CONTAO_DIR}/vendor/bin/contao-console" ]
      then
        COMMAND="${PHP_CLI} "${CONTAO_DIR}/vendor/bin/contao-console" debug:dotenv"
      else
        echo "Weder bin/console noch vendor/bin/contao-console gefunden. Irgendetwas stimmt hier nicht!"; exit
      fi
    fi
    $COMMAND \
    | grep DATABASE_URL \
    | sed -e's/^ *DATABASE_URL *//' \
    | cut -d' ' -f1
    return $?
}

function get_db_user() {
    get_db_param 'database_user'
}
function get_db_password() {
    get_db_param 'database_password'
}
function get_db_host() {
    get_db_param 'database_host'
}
function get_db_name() {
    get_db_param 'database_name'
}
function get_db_port() {
    get_db_param 'database_port'
}

DBUSER=$(get_db_user)
if [ -z $DBUSER ] || [ 'null' == $DBUSER ]
then
  if [ $DEBUG -gt 0 ]
  then
    echo "Parameter nicht parameters.yml, sondern in .env Dateien? (z.B. in Contao 5)"
    echo "Verwende anderen Ansatz zur Bestimmung der Datenbank Zugangsdaten!"
  fi
  DBURL=$(get_db_url_from_env)
  if [ $DEBUG -gt 0 ]
  then
    echo "Ausgelesene DBURL ist '$DBURL'. Versuche nun, diese zu zerlegen:"
  fi
  # mysql://user:pass@host:port/databasename[?optional_parameters]
  DBURL_PARAMETERS=$(echo $DBURL | sed -e's/mysql:\/\///' | cut -d'?' -f1)
  if [ $DEBUG -gt 0 ]
  then
    echo "Erster Schritt, ohne Protokoll ergibt: '$DBURL_PARAMETERS'"
  fi
  # user:pass@host:port/databasename
  DBUSER=$(echo $DBURL_PARAMETERS | cut -d':' -f1)
  #echo "(a) User '$USER' extrahiert"
  DBPASSWORD=$(echo $DBURL_PARAMETERS | cut -d':' -f2 | cut -d'@' -f1)
  #echo "(b) Password '$DBPASSWORD' extrahiert"
   if [ $(echo $DBURL_PARAMETERS | grep -o ":" | wc -l) -eq 1 ]
   then
     #echo "nur ein Doppelpunkt, also Muster ohne port: user:pass@host/databasename[?optional_parameters] in $DBURL_PARAMETERS"
     DBHOST=$(echo $DBURL_PARAMETERS | cut -d':' -f2 | cut -d'@' -f2 | cut -d'/' -f1)
     #echo "Verwende Standardport 3306"
     DBPORT='3306'
   else
     #echo "mehr als ein Doppelpunkt, also Muster mit Port: user:pass@host:port/databasename[?optional_parameters] in $DBURL_PARAMETERS"
     DBHOST=$(echo $DBURL_PARAMETERS | cut -d':' -f2 | cut -d'@' -f2)
     DBPORT=$(echo $DBURL_PARAMETERS | cut -d':' -f3 | cut -d'/' -f1)
   fi
  #echo "(c1) Host '$DBHOST' extrahiert"
  #echo "(c2) Port '$DBPORT' extrahiert bzw. gesetzt"
  DBNAME=$(echo $DBURL_PARAMETERS | cut -d'/' -f2)
  #echo "(d) DB-Name '$DBNAME' extrahiert"

else
  # Contao 4: restliche Parameter
  DBPASSWORD=$(get_db_password)
  DBHOST=$(get_db_host)
  DBNAME=$(get_db_name)
  DBPORT=$(get_db_port)
fi

if [ $DEBUG -gt 0 ]
then
  echo "Verwende DBUSER=$DBUSER, DBPASSWORD=$DBPASSWORD, DBHOST=$DBHOST, DBPORT=$DBPORT, DBNAME=$DBNAME"
fi

# Hat weder der Contao 4-, noch der Contao 5-Ansatz funktioniert?
if [ -z $DBUSER ]  || [ 'null' == $DBUSER ] || [ -z $DBPASSWORD ] || [ -z $DBHOST ] || [ -z $DBNAME ] || [ -z $DBPORT ]
then
  echo "Konnte Datenbank-Zugangsdaten nicht (vollständig) bestimmen"
  exit 1
fi

IGNORE_TABLES=''

if [ -n "${SKIP_THESE_TABLES}" ]
then
    # die angegebenen Tabellen nicht in die Datenbanksicherung aufnehmen
    for TABLE in ${SKIP_THESE_TABLES}
    do
        IGNORE_TABLES="${IGNORE_TABLES} --ignore-table=${DBNAME}.${TABLE}"
    done
fi

# write credentials file so we don't have to specify the password as a command line argument
echo '[mysqldump]' > "${TARGET_DIR}/my.cnf"
echo "user='${DBUSER}'" >> "${TARGET_DIR}/my.cnf"
echo "password='${DBPASSWORD}'" >> "${TARGET_DIR}/my.cnf"


${MYSQLDUMP} \
    --defaults-extra-file="${TARGET_DIR}/my.cnf" \
    --host=${DBHOST} \
    --port=${DBPORT} \
    ${DBOPTIONS} \
    ${IGNORE_TABLES} \
    ${DBNAME} \
    > "${TARGET_DIR}/${DUMP_NAME}_${NOW}.sql" \
    && ${MYSQLDUMP} \
    --defaults-extra-file="${TARGET_DIR}/my.cnf" \
    --host=${DBHOST} \
    --port=${DBPORT} \
    --no-data \
    ${DBOPTIONS} \
    ${DBNAME} \
    ${SKIP_THESE_TABLES} \
    >> "${TARGET_DIR}/${DUMP_NAME}_${NOW}.sql" \
    && gzip --force "${TARGET_DIR}/${DUMP_NAME}_${NOW}.sql"


# Alte Backups rollierend löschen

if [ ${PURGE_AFTER_DAYS} -gt 0 ]
then
    assert_command 'rm' '(Behebung: PURGE_AFTER_DAYS=0 setzen)' || return

    # Varaible gesetzt? Ansonsten Default verwenden.
    if [ -z "${PURGE_TIMESTAMP_FORMAT}" ]
    then
        PURGE_TIMESTAMP_FORMAT='%Y-%m-%d'
    fi

    # Betriebssystem ermitteln um den date-Aufruf entsprechend zu parametrisieren.
    # Linux vs. BSD (also auch MacOS).
    #
    # Nur, falls das Betriebssystem nicht bereits in der Variablen OS angegeben wurde (siehe main.sh)

    if [ -z "${OS}" ]
    then
        ## assert_command 'uname' "(Behebung: 'OS' setzen)" || return

        OS=$(uname)
    fi

    if [ "${OS}" = 'Linux' ]
    then
        OLD=$(date +"${PURGE_TIMESTAMP_FORMAT}" -d"${PURGE_AFTER_DAYS} days ago")
    elif [[ ("${OS}" == 'FreeBSD') || ("${OS}" == 'Darwin') ]]
    then
        OLD=$(date -v -${PURGE_AFTER_DAYS}d +"${PURGE_TIMESTAMP_FORMAT}")
    else
        echo "Fehler in $0: unknown operating system (Behebung: Ticket eröffnen)"
        return
    fi

    if [ $HIDE_ON_WEB_CALL -eq 0 ]
    then
      echo "Backup-Vezeichnis ist: ${TARGET_DIR}"
    fi
    echo "loesche altes Backup vom '${OLD}'"

    rm -f "${TARGET_DIR}/${DUMP_NAME}_${OLD}"*
fi

if [ $HIDE_ON_WEB_CALL -eq 0 ]
then
  if ! is_disabled 'ls'
  then
    echo "aktuell vorhandene Backups:"
    ( cd "${TARGET_DIR}" && ls -lh "${DUMP_NAME}"_* )
  fi
fi

rm "${TARGET_DIR}/my.cnf" || echo "konnte (temporäre) Passwortdatei nicht löschen"

if [ $HIDE_ON_WEB_CALL -eq 0 ]
then
  echo "Backup ${DUMP_NAME} beendet (gespeichert in ${TARGET_DIR})"
fi

## EOF ##
