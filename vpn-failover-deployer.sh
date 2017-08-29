#!/bin/bash
# Deploy single client VPNs on failover IPs
# Very useful for home servers

# Server configuraiton
vpnname="" # Give a lowercase simple VPN name
localip="" # Listening IP local and public

# Both configuration
port="1194" # Default 1194
proto="udp" # Protocol: udp better ping, tcp better packet delivery
routing="tun" # Routing: routed tunnel (tun) or ethernet tunnel (tap)
vpnsubnet="10.8.0.0" # VPN subnet (IP range)
vpnnetmask="255.255.255.0" # VPN Netmask

# Client configuration
clientconnectip="${localip}# The IP clients will connect to; default set to localip assuming it is public or reachable locally

# Firewall configuration
failover="${localip}" # Server listening public IP
vpnnetwork="${vpnsubnet}/24" # VPN Network, default 10.8.0.0/24
vpnclient="10.8.0.2" # Expected failover IP

if [ -z "${vpnname}" ]||[ -z "${localip}" ]; then
	echo "This script is non-interactive, please edit the configuration at its beginning."
	exit
fi

apt update
apt -y install openvpn easy-rsa

# easy-rsa
echo "Copying easy-rsa"
cp -r /usr/share/easy-rsa/ /etc/openvpn
chown -R root:root /etc/openvpn/easy-rsa/

# Key generation
echo "Building keys (might take a while)"
cd /etc/openvpn/easy-rsa/
source vars
./clean-all
./build-dh
./pkitool --initca
./pkitool --server server
openvpn --genkey --secret keys/ta.key
./build-key ${vpnname}-client

echo "Creating directories"
mkdir -pv "/etc/openvpn/server/${vpnname}"
mkdir -pv "/etc/openvpn/client/${vpnname}"
echo "Copying keys"
cp keys/ca.crt keys/ta.key keys/server.crt keys/server.key keys/dh2048.pem "/etc/openvpn/server/${vpnname}"
cp keys/ca.crt keys/ta.key keys/${vpnname}-client.crt keys/${vpnname}-client.key "/etc/openvpn/client/${vpnname}"

echo "Creating jail"
mkdir -pv /etc/openvpn/jail/tmp

# Generating firewall script
touch "/etc/openvpn/firewall_${vpnname}.sh"
echo "#!/bin/bash
# This simple script is intended to route traffic from a VPN through a failover IP

# Script

if [ -z \"$1\" ]; then
        echo \"Info! Please specify enable or disable\"
        exit
fi
if [ \"$1\" != \"enable\" ]&&[ \"${1}\" != \"disable\" ];then
        echo \"Info! Please specify enable or disable\"
        exit
fi

# Enable rule
if [ \"$1\" == \"enable\" ];then
	echo \"Enable VPN rules\"
	# Allow forward
	echo \"Allowing forwarding\"
	echo 1 > /proc/sys/net/ipv4/ip_forward

	# Apply table
	echo \"Applying iptables:\"
	echo \" -> Redirect failover: ${failover} to client: ${vpnclient} on network: ${vpnnetwork}\"
	# Any traffic incoming to the failover IP is routed into the VPN client
	iptables -t nat -A PREROUTING -d \"${failover}\" -j DNAT --to-destination \"${vpnclient}\"
	# Anything traffic sent by the VPN network to outside the VPN network is routed through the failover IP
	iptables -t nat -A POSTROUTING -s \"${vpnnetwork}\" ! -d \"${vpnnetwork}\" -j SNAT --to-source \"${failover}\"
	echo \"[OK] Job done\"
	exit
fi

# Disable rules
if [ \"$1\" == \"disable\" ];then
	echo \"Disable VPN rules\"
	# Disallow forward
	echo \"Disallow forwarding\"
	echo 0 > /proc/sys/net/ipv4/ip_forward

	# Remove table
	echo \"Removing iptables:\"
	echo \" <- Redirect failover: ${failover} to client: ${vpnclient} on network: ${vpnnetwork}\"
	iptables -t nat -D PREROUTING -d \"${failover}\" -j DNAT --to-destination \"${vpnclient}\"
	iptables -t nat -D POSTROUTING -s \"${vpnnetwork}\" ! -d \"${vpnnetwork}\" -j SNAT --to-source \"${failover}\"

	echo \"[OK] Job done\"
	exit
fi\" > "/etc/openvpn/firewall_${vpnname}.sh"
chmod +x "/etc/openvpn/firewall_${vpnname}.sh"


systemctl restart openvpn@openvpn.service
