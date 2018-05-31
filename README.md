# vpn-failover-deployer
Deploy single client VPNs over failover IPs, useful for home servers

This acts as if the server additional IP was your home server actual IP.
It allows you to:
* Hide your home IP
* Benefit from host anti-DDoS
* Stop bothering with port redirections
* Have a fixed IP address

## Requirements
- Have a dedicated server with at least two IPs (one additional IP per VPN)
- Have OpenVPN installed
- Have iptables available (most distro do)

## Compatibility
Was tested only with Debian 9, might work with other distro.
You might want to disable IPv6 for better compatibility with OpenVPN.

## How to use

### On the server

* Download the script and make it executable
```bash
wget https://raw.githubusercontent.com/UltimateByte/vpn-failover-deployer/master/vpn-failover-deployer.sh
chmod +x vpn-failover-deployer.sh
```

* Edit the required config
```bash
nano vpn-failover-deployer.sh

# Server configuration (required)
vpnname="" # Give a lowercase simple VPN name
serverip="" # Listening IP local and public
failover="" # VPN dedicated IP
```
`vpnname` is just a name to know which VPN this is (you can deploy multiple ones)  
`serverip` is the IP of your VPN server, usually the main IP of your machine  
`failover` is the additional IP you wish to bind your server to  

* Edit optional config if needed (only if you know what you're doing)
```bash
# Both configuration
port="1194" # Default 1194
proto="udp" # Protocol: udp better ping, tcp better packet delivery
routing="tun" # Routing: routed tunnel (tun) or ethernet tunnel (tap)
vpnsubnet="10.8.0.0" # VPN subnet (IP range)
vpnnetmask="255.255.255.0" # VPN Netmask
```

* Run the script
```bash
./vpn-failover-deployer.sh
```

### On the client

* Copy the generated client config from your OpenVPN server to your OpenVPN client, respecting the same directory tree. The config is located in the server in:
```
/etc/openvpn/client/
```

* Move the config from the client dir to openvpn dir, for example
```bash
cd /etc/openvpn
mv client/*.conf /etc/openvpn
```

* Secure these certificates and config files

```bash
chown -R root:root /etc/openvpn
chmod 750 /etc/openvpn/client /etc/openvpn/easy-rsa*
```

* Start the service (replace ${vpnname} with your actual server name)
```bash
systemctl start openvpn@${vpnname}.service
```
