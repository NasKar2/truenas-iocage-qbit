# truenas-iocage-qbit
Install qbittorrent to truenas 12
#### https://github.com/NasKar2/truenas-iocage-qbit.git

Script to create an iocage jail on TrueNAS 12.2 from scratch in a jails for QBITTORRENT

## Install QBITTORRENT in fresh Jail

### Prerequisites

If you are going to going to use the vpn, you will need add a preinit task in the webui to run the following command as well as run it once before you setup the jail. This adds a rule to the default devfs_rules>
devfs rule -s 4 add path 'tun*' unhide

### Required

- JAIL_IP : IP address of your jail
- DEFAULT_GW_IP : Default gateway IP address

### Optional

- INTERFACE: Defaults to 'vnet0'
- VNET : Defaults to 'on'
- JAIL_NAME : Defaults to 'qbittorrent'
- POOL_PATH : Defaults to your pool path in my case /mnt/v1
- APPS_PATH : Defaults to 'apps'
- QBITTORRENT_DATA : Defaults to 'qbittorrent"
- MEDIA_LOCATION : Defaults to 'media'
- TORRENTS_LOCATION : Defaults to 'torrents'
- USE_BASEJAIL : Defaults to "-b" to create a basejail

### Details

Create qbittorrent-config.

Minimal config file. Other parameters set to defaults.
```
JAIL_IP="192.168.5.76"
DEFAULT_GW_IP="192.168.5.1"
```
Full config file
```
JAIL_IP="192.168.5.76"
DEFAULT_GW_IP="192.168.5.1"
INTERFACE="vnet0"
VNET="on"
JAIL_NAME="qbittorrent"
POOL_PATH="/mnt/v1"
APPS_PATH="apps"
QBITTORRENT_DATA="qbittorrent"
TORRENTS_LOCATION="torrents"
```
Create openvpn.conf and pass.txt files in config directory. Example files shown, you have to edit the details
```
client
dev tun
proto udp
remote vpnaddress.com 1194
resolv-retry infinite
nobind
persist-key
persist-tun
persist-remote-ip
ca vpn.crt

tls-client
remote-cert-tls server
#auth-user-pass
auth-user-pass /config/pass.txt
comp-lzo
verb 3

auth SHA256
cipher AES-256-CBC

<ca>
-----BEGIN CERTIFICATE-----
MIIESDC...............
-----END CERTIFICATE-----
</ca>

```
pass.txt
```
vpn_username
vpn_password
```

