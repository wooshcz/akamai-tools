#!/bin/bash

BASE_PATH=`dirname "$0"`
HOSTNAMES_LIST_FILE=${BASE_PATH}/staging-hostnames-list.txt
HOSTNAMES_LIST=`grep -v -E "^#(.*)" ${HOSTNAMES_LIST_FILE}`
BUILD_HOSTS_FILE=${BASE_PATH}/hosts.staging
DEFAULT_HOSTS_FILE=${BASE_PATH}/hosts.default
STATIC_HOSTS_FILE=${BASE_PATH}/staging-static-config.txt

# Print a usage message.
usage() {
  echo "Usage: $0 [ apply | build | init | clean | reset ]" 1>&2
}

if [[ ${BASH_ARGC} -ne 1 ]]; then
  usage
  exit 1
fi

apply() {
  echo "Applying the built configuration ..."
  if [[ -f ${STATIC_HOSTS_FILE} ]]; then
    cat ${STATIC_HOSTS_FILE} >> /etc/hosts
    echo "Adding the static configuration into /etc/hosts"
  fi
  if [[ -f ${BUILD_HOSTS_FILE} ]]; then
    cat ${BUILD_HOSTS_FILE} >> /etc/hosts
    echo "Adding the built hosts into /etc/hosts"
  else
    echo "No configuration has been built yet, you might want to run '$0 build' first"
    exit 1
  fi
}

init() {
  echo "Initializing the staging-cli, saving the default hosts file ..."
  cat /etc/hosts > ${DEFAULT_HOSTS_FILE}
  echo -n "" > ${BUILD_HOSTS_FILE}
}

reset() {
  echo "Restoring the hosts file to the default state ..."
  if [[ -f ${DEFAULT_HOSTS_FILE} ]]; then
    cat ${DEFAULT_HOSTS_FILE} > /etc/hosts
  else
    echo "Default hosts file has not been saved yet. Please run '$0 init' first"
    exit 1
  fi
}

clean() {
  echo "Clearing the built configuration ..."
  echo -n "" > ${BUILD_HOSTS_FILE}
}

build() {
  echo "Building the configuration ..."
  CNTR=0
  ARR_LEN=`wc -w <<< "${HOSTNAMES_LIST}"`
  echo "Found ${ARR_LEN} hostnames in the list"
  for hostname in ${HOSTNAMES_LIST}; do
    ((CNTR++))
    echo -n "${CNTR}/${ARR_LEN} | Processing ${hostname}"
    hostname=`echo ${hostname} | tr -d '[:space:]'`
    DIG_CNAME=`dig ${hostname} +short | grep -E "\.(edgekey|edgesuite)\.net\.$"`;
    if [[ ${#DIG_CNAME} -gt 0 ]]; then
      echo -n -e " | is hosted on Akamai"
      STAGING_CNAME=`echo ${DIG_CNAME} | sed -E 's/(edgekey|edgesuite)\.net/\1-staging\.net/'`;
      STAGING_IP_OUT=`dig ${STAGING_CNAME} +short | tail -1`;
      echo -n -e " | staging IP address: ${STAGING_IP_OUT}"
      echo -e "${STAGING_IP_OUT}\t${hostname}" >> ${BUILD_HOSTS_FILE}
    else
      echo -n -e " | skipping"
    fi
    echo -e " | done"
  done
}

if [[ "${BASH_ARGV}" == "apply" ]]; then
  reset
  apply
fi

if [[ "${BASH_ARGV}" == "clean" ]]; then
  clean
fi

if [[ "${BASH_ARGV}" == "init" ]]; then
  init
fi

if [[ "${BASH_ARGV}" == "build" ]]; then
  clean
  build
fi

if [[ "${BASH_ARGV}" == "reset" ]]; then
  reset
fi
