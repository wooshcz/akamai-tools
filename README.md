# Bash Utils for working with the Akamai CDN

## staging-cli.sh
Bash script that is able to extract the currently used Edge Servers IP addresses for Akamai-hosted domains and apply these IPs into the /etc/hosts file to route the local traffic to Akamai Staging network. This is useful to test changes on Akamai Staging before deploying to production.

### Requirements
* jq - Command-line JSON processor
* bash - GNU Bourne-Again SHell
* dig - DNS lookup utility

## staging-cli.py
Python flavor of the above ...

### Requirements
* python3

### Usage

```
   $ ./staging-cli.sh
   Usage: ./staging-cli.sh [ apply | build | init | clean | reset ]
```

* apply - applies the already built IP-Host entries into the main /etc/hosts. This needs to be run as sudo.
* build - this takes the configuration file with the hostnames and builds the IP-Host mapping. This needs to be run first before the apply action can be used.
* init - initialization of the tool. This takes a backup of the default values in /etc/hosts and stores them locally for reference.
* clean - clears the built IP-Host mapping from disk -- ./hosts.staging
* reset - reverts the /etc/hosts into the default state. This needs to be run as sudo -- sudo cp ./hosts.default /etc/hosts

### Typical examples

```
   $ ./staging-cli.sh init # initialize the tool
   $ vim ./staging-hostnames-list.txt # edit the list hostnames manually
   $ ./staging-cli.sh build # build the IP-Host mapping
   $ sudo ./staging-cli.sh apply # apply the built mapping into /etc/hosts
   $ sudo ./staging-cli.sh reset # revert the /etc/hosts into the default state
   $ ./staging-cli.sh clean # clear the built IP-Host mapping from disk
```


