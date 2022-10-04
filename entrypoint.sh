#!/bin/bash

set -euo pipefail

parse_config() {
  config_file="$1"
  prefix="$2"
  # If the config file exists, read it into the env
  if [ -f "${config_file}" ]; then
    while IFS='=' read -r n v; do
      echo "${n}=${v}";

      # skip if a _FILE version exists
      vname="${prefix}_${n//-/_}_FILE";
      if [[ ! -v "${vname}" ]]; then
        export "${prefix}_${n//-/_}=${v}";
      fi
    done <"${config_file}"
  fi
}

parse_env() {
  prefix="$1"
  # turn PDNS_var_FILE info PDNS_var=<content of file> for docker secrets
  while IFS='=' read -r -d '' n v; do
      if [[ $n = ${prefix}_* && $n = *_FILE ]]; then
          export "${n/_FILE}=$(<$v)";
          unset "${n}"
      fi
  done < <(env -0)
}


pdns_config="/etc/pdns/pdns.conf"
pdns_prefix="PDNS"
recursor_config="/etc/pdns/recursor.conf"
recursor_prefix="RECURSOR"

parse_config "${pdns_config}" "${pdns_prefix}"
parse_config "${recursor_config}" "${recursor_prefix}"

parse_env "${pdns_prefix}"
parse_env "${recursor_prefix}"

# Configure sqlite env vars
export PDNS_gsqlite3_database="${PDNS_gsqlite3_database:-/data/powerdns.sqlite3}"

SQLITE_COMMAND="$(which sqlite3) ${PDNS_gsqlite3_database}"

# Initialize DB if needed
if [ ! -f "${PDNS_gsqlite3_database}" ]; then
    $SQLITE_COMMAND < /usr/share/doc/pdns/schema.sqlite3.sql
    chown pdns:pdns "${PDNS_gsqlite3_database}"
fi

if [ "${PDNS_superslave:-no}" == "yes" ]; then
    # Configure supermasters if needed
    if [ "${SUPERMASTER_IPS:-}" ]; then
        $SQLITE_COMMAND "DELETE FROM supermasters;"
        SQLITE_INSERT_SUPERMASTERS=''
        if [ "${SUPERMASTER_COUNT:-0}" == "0" ]; then
            SUPERMASTER_COUNT=10
        fi
        for ((i=0; i<=${SUPERMASTER_COUNT}; i++)); do
            SUPERMASTER_HOST=$(echo ${SUPERMASTER_HOSTS:-} | awk -v col="$i" '{ print $col }')
            SUPERMASTER_IP=$(echo ${SUPERMASTER_IPS} | awk -v col="$i" '{ print $col }')
            if [ -z "${SUPERMASTER_HOST:-}" ]; then
                SUPERMASTER_HOST=$(hostname -f)
            fi
            if [ "${SUPERMASTER_IP:-}" ]; then
                SQLITE_INSERT_SUPERMASTERS="${SQLITE_INSERT_SUPERMASTERS} INSERT INTO supermasters VALUES('${SUPERMASTER_IP}', '${SUPERMASTER_HOST}', 'admin');"
            fi
        done
        $SQLITE_COMMAND "$SQLITE_INSERT_SUPERMASTERS"
    fi
fi

# re-create pdns config file from template
envtpl < /pdns.conf.tpl > "${pdns_config}"
chown pdns:pdns "${pdns_config}"

# re-create recursor config file from template
envtpl < /recursor.conf.tpl > "${recursor_config}"
chown recursor:recursor "${recursor_config}"

# start the caching name server
/usr/sbin/pdns_recursor &

# start the authoritative name server
/usr/sbin/pdns_server &

wait -n

exit $?

