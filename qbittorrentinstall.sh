#!/bin/sh
# Build an iocage jail under FreeNAS 11.1 with  qbittorrent
# https://github.com/NasKar2/sepapps-freenas-iocage

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

# Initialize defaults
JAIL_IP=""
DEFAULT_GW_IP=""
INTERFACE=""
VNET=""
JAIL_NAME=""
POOL_PATH=""
APPS_PATH=""
QBITTORRENT_DATA=""
MEDIA_LOCATION=""
TORRENTS_LOCATION=""
USE_BASEJAIL="-b"

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/qbittorrent-config
CONFIGS_PATH=$SCRIPTPATH/configs
DB_ROOT_PASSWORD=$(openssl rand -base64 16)
DB_PASSWORD=$(openssl rand -base64 16)
ADMIN_PASSWORD=$(openssl rand -base64 12)
RELEASE=$(freebsd-version | cut -d - -f -1)"-RELEASE"

# Check for qbittorrent-config and set configuration
if ! [ -e $SCRIPTPATH/qbittorrent-config ]; then
  echo "$SCRIPTPATH/qbittorrent-config must exist."
  exit 1
fi

# Check that necessary variables were set by qbittorrent-config
if [ -z $JAIL_IP ]; then
  echo 'Configuration error: JAIL_IP must be set'
  exit 1
fi
if [ -z $DEFAULT_GW_IP ]; then
  echo 'Configuration error: DEFAULT_GW_IP must be set'
  exit 1
fi
if [ -z $INTERFACE ]; then
  INTERFACE="vnet0"
  echo "INTERFACE defaulting to 'vnet0'"
fi
if [ -z $VNET ]; then
  VNET="on"
  echo "VNET defaulting to 'on'"
fi

if [ -z $POOL_PATH ]; then
  POOL_PATH="/mnt/$(iocage get -p)"
  echo "POOL_PATH defaulting to "$POOL_PATH
fi
if [ -z $APPS_PATH ]; then
  APPS_PATH="apps"
  echo "APPS_PATH defaulting to 'apps'"
fi

if [ -z $JAIL_NAME ]; then
  JAIL_NAME="qbittorrent"
  echo "JAIL_NAME defaulting to 'qbittorrent'"
fi
if [ -z $QBITTORRENT_DATA ]; then
  QBITTORRENT_DATA="qbittorrent"
  echo "QBITTORRENT_DATA defaulting to 'qbittorrent'"
fi
if [ -z $MEDIA_LOCATION ]; then
  MEDIA_LOCATION="media"
  echo "MEDIA_LOCATION defaulting to 'media'"
fi
if [ -z $TORRENTS_LOCATION ]; then
  TORRENTS_LOCATION="torrents"
  echo "TORRENTS_LOCATION defaulting to 'torrents'"
fi


#
# Create Jail
#echo '{"pkgs":["nano","mono","mediainfo","sqlite3","ca_root_nss","curl"]}' > /tmp/pkg.json
echo '{"pkgs":["nano","curl","qbittorrent-nox","openvpn","ca_root_nss"]}' > /tmp/pkg.json
if ! iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r "${RELEASE}" ip4_addr="${INTERFACE}|${JAIL_IP}/24" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}" allow_raw_sockets="1" allow_tun="1"
then
	echo "Failed to create jail"
	exit 1
fi
rm /tmp/pkg.json

#
# needed for installing from ports
#mkdir -p ${PORTS_PATH}/ports
#mkdir -p ${PORTS_PATH}/db

mkdir -p ${POOL_PATH}/${APPS_PATH}/${QBITTORRENT_DATA}
mkdir -p ${POOL_PATH}/${MEDIA_LOCATION}/videos/tvshows
mkdir -p ${POOL_PATH}/${TORRENTS_LOCATION}
#chown -R media:media ${POOL_PATH}/${MEDIA_LOCATION}
echo "mkdir -p '${POOL_PATH}/${APPS_PATH}/${QBITTORRENT_DATA}'"

qbittorrent_config=${POOL_PATH}/${APPS_PATH}/${QBITTORRENT_DATA}

iocage exec ${JAIL_NAME} 'sysrc ifconfig_epair0_name="epair0b"'

# create dir in jail for mount points
iocage exec ${JAIL_NAME} mkdir -p /usr/ports
iocage exec ${JAIL_NAME} mkdir -p /var/db/portsnap
iocage exec ${JAIL_NAME} mkdir -p /config
iocage exec ${JAIL_NAME} mkdir -p /mnt/media
iocage exec ${JAIL_NAME} mkdir -p /mnt/configs
iocage exec ${JAIL_NAME} mkdir -p /mnt/torrents

#
# mount ports so they can be accessed in the jail
#iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/ports /usr/ports nullfs rw 0 0
#iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/db /var/db/portsnap nullfs rw 0 0

iocage fstab -a ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${qbittorrent_config} /config nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${MEDIA_LOCATION} /mnt/media nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${TORRENTS_LOCATION} /mnt/torrents nullfs rw 0 0

#iocage restart ${JAIL_NAME}
# add media user
iocage exec ${JAIL_NAME} "pw user add media -c media -u 8675309  -d /nonexistent -s /usr/bin/nologin"  
# add media group to media user
#iocage exec ${JAIL_NAME} pw groupadd -n media -g 8675309
#iocage exec ${JAIL_NAME} pw groupmod media -m media
#iocage restart ${JAIL_NAME} 

iocage exec ${JAIL_NAME} chown -R qbittorrent:qbittorrent /config
iocage exec ${JAIL_NAME} sysrc qbittorrent_enable="YES"
#iocage exec ${JAIL_NAME} sysrc qbittorrent_user=media
#iocage exec ${JAIL_NAME} sysrc qbittorrent_group=media
iocage exec ${JAIL_NAME} sysrc qbittorrent_confdir="/config"

# ipfw_rules
iocage exec ${JAIL_NAME} cp -f /mnt/configs/ipfw_rules /config/ipfw_rules
  
# openvpn.conf
iocage exec ${JAIL_NAME} cp -f /mnt/configs/openvpn.conf /config/openvpn.conf
iocage exec ${JAIL_NAME} cp -f /mnt/configs/pass.privado.txt /config/pass.privado.txt

iocage exec ${JAIL_NAME} "chown 0:0 /config/ipfw_rules"
iocage exec ${JAIL_NAME} "chmod 600 /config/ipfw_rules"
iocage exec ${JAIL_NAME} sysrc firewall_enable="YES"
iocage exec ${JAIL_NAME} sysrc firewall_script="/config/ipfw_rules"
iocage exec ${JAIL_NAME} sysrc openvpn_enable="YES"
iocage exec ${JAIL_NAME} sysrc openvpn_dir="/config"
iocage exec ${JAIL_NAME} sysrc openvpn_configfile="/config/openvpn.conf"

iocage exec ${JAIL_NAME} service ipfw start
iocage exec ${JAIL_NAME} service openvpn start

#
# Make pkg upgrade get the latest repo
iocage exec ${JAIL_NAME} mkdir -p /usr/local/etc/pkg/repos/
iocage exec ${JAIL_NAME} cp -f /mnt/configs/FreeBSD.conf /usr/local/etc/pkg/repos/FreeBSD.conf
#iocage exec ${JAIL_NAME} echo -e "FreeBSD: {\nurl: \"pkg+http://pkg.FreeBSD.org/\${ABI}/latest\"\n}" > /usr/local/etc/pkg/repos/FreeBSD.conf

#
# Upgrade to the lastest repo
iocage exec ${JAIL_NAME} pkg upgrade -y
iocage restart ${JAIL_NAME}

#iocage exec ${JAIL_NAME} sed -i '' "s|${old2_user}|${new2_user}|" /usr/local/etc/rc.d/deluge_web


#iocage exec ${JAIL_NAME} sed -i '' 's/\"allow_remote": \false/\"allow_remote": \true/g' /configs/core.conf
iocage restart ${JAIL_NAME} 
echo "qbittorrent should be available at http://${JAIL_IP}:8080"

