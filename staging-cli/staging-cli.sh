#!/bin/bash

BASE_PATH=`dirname "$0"`
HOSTNAMES_LIST_FILE=${BASE_PATH}/staging-hostnames-list.txt
HOSTNAMES_LIST=`grep -v -E "^#(.*)" ${HOSTNAMES_LIST_FILE}`
BUILD_HOSTS_FILE=${BASE_PATH}/hosts.staging
DEFAULT_HOSTS_FILE=${BASE_PATH}/hosts.default
STATIC_HOSTS_FILE=${BASE_PATH}/staging-static-config.txt
DEBUG_FLAG=false

# Print a usage message.
usage() {
  echo "Usage: $0 [ apply | build | init | clean | reset ]" 1>&2
}

if [[ ${BASH_ARGC} -ne 1 ]]; then
  usage
  exit 1
fi

digjson() {
  digjson=$( dig $hostname +nocomments +noquestion +noauthority +noadditional +nostats  | awk '{if (NR>3) { print }}' | tr '\t' ' ' | tr -s ' ' | jq -R 'split(" ")|{Name:.[0],TTL:.[1],Class:.[2],Type:.[3],IpAddress:.[4]}' | jq --slurp . )
  diglen=$( echo $digjson | jq length )
  if [[ "$DEBUG_FLAG" == "true" ]]; then
    echo "[DEBUG] $digjson"
  fi
}

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
    DIG_EDGEKEY=""
    DIG_AKADNS=""
    DIG_EDGE=""
    digjson
    i=0
    while [[ $i -lt $diglen ]] ; do
      digline=$( echo $digjson | jq .[$i] )
      IS_EDGEKEY=`echo ${digline} | jq .IpAddress | tr -d '"' | grep -E "\.(edgekey|edgesuite)\.net\.$"`;
      IS_AKADNS=`echo ${digline} | jq .IpAddress | tr -d '"' | grep -E "\.globalredir\.akadns.net\.$"`;
      IS_EDGE=`echo ${digline} | jq .IpAddress | tr -d '"' | grep -E "\.akamaiedge\.net\.$"`;
      if [[ ${#IS_EDGEKEY} -gt 0 ]]; then
        DIG_EDGEKEY=$IS_EDGEKEY
      fi
      if [[ ${#IS_AKADNS} -gt 0 ]]; then
        DIG_AKADNS=$IS_AKADNS
      fi
      if [[ ${#IS_EDGE} -gt 0 ]]; then
        DIG_EDGE=$IS_EDGE
      fi
      (( i += 1 ))
    done

    if [[ "$DEBUG_FLAG" == "true" ]]; then
      echo "[DEBUG] Edgekey: $DIG_EDGEKEY, Akadns: $DIG_AKADNS, Edge: $DIG_EDGE"
    fi

    if [[ ${#DIG_EDGEKEY} -gt 0 ]] && [[ ${#DIG_AKADNS} -gt 0 ]] && [[ ${#DIG_EDGE} -gt 0 ]]; then
      echo -n -e " | is hosted on Akamai with Akadns"
      STAGING_CNAME=`echo ${DIG_EDGE} | sed -E 's/(akamaiedge)\.net/\1-staging\.net/'`;
      STAGING_IP_OUT=`dig ${STAGING_CNAME} +short | tail -1`;
      echo -n -e " | staging IP address: ${STAGING_IP_OUT}"
      echo -e "${STAGING_IP_OUT}\t${hostname}" >> ${BUILD_HOSTS_FILE}
    elif [[ ${#DIG_EDGEKEY} -gt 0 ]] ; then
      echo -n -e " | is hosted on Akamai"
      STAGING_CNAME=`echo ${DIG_EDGEKEY} | sed -E 's/(edgekey|edgesuite)\.net/\1-staging\.net/'`;
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
