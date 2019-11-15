#!/bin/bash

### BEGIN INIT INFO
# Provides:		fw.sh
# Required-Start:	$all
# Required-Stop:	$all
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	Firewall
# Description:		Establece el firewall en este router
### END INIT INFO

# Activar enrutamiento
echo 1 > /proc/sys/net/ipv4/ip_forward

RED_LOCAL=192.168.5.0/24
RED_DMZ=192.168.50.0/24
RED_CLASE=172.20.202.0/24
IFACE_OUT=enp2s5
IP_MAIL=192.168.50.4
IP_CHAT=$IP_MAIL
IP_DNS=192.168.50.2
IP_AD=$IP_DNS
IP_WEB=192.168.50.3
IP_DHCP=192.168.5.91
IP_ROUTER=172.20.202.35

echo "Aplicando Reglas de Firewall..."

## Borrar todas las reglas
echo "Reglas borradas:"
iptables -F && echo "  Tabla filter"
iptables -t nat -F && echo "  Tabla nat"

## Politicas por defecto
echo "Políticas por defecto:"
iptables -P INPUT DROP && echo "  INPUT -> DROP"
iptables -P OUTPUT DROP && echo "  OUTPUT -> DROP"
iptables -P FORWARD DROP && echo "  FORWARD -> DROP"

iptables -A FORWARD -s $RED_CLASE -j LOG --log-prefix 'IPTABLES-CORUSCANT-FORWARD# '
iptables -A INPUT -s $RED_CLASE -j LOG --log-prefix 'IPTABLES-CORUSCANT-INPUT# '


echo "Aceptando todos los paquetes cuyo estado sea 'ESTABLISHED' o 'RELATED'."
## Aceptar todos los paquetes que hayan establecido conexion
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "Aceptando los siguientes puertos en el Router:"
## Aceptar puertos en router
# Poder meterse por SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT && echo "  INPUT: 22 (SSH)"
# Necesarios para acceder a la red
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT && echo "  OUTPUT: 80 (HTTP)"
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT && echo "  OUTPUT: 443 (HTTPS)"
iptables -A OUTPUT -p tcp --dport 21 -j ACCEPT && echo "  OUTPUT: 21 (FTP)"
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT && echo "  OUTPUT: 53 (DNS)"
# Poder hacer Ping
iptables -A OUTPUT -p icmp -j ACCEPT && echo "  OUTPUT: icmp (ping)"
iptables -A INPUT -s $RED_DMZ -p icmp -j ACCEPT && echo "  INPUT: icmp (ping)"
iptables -A FORWARD -s $RED_DMZ -p icmp -j ACCEPT && echo "  FORWARD: icmp (ping), source: $RED_DMZ"
iptables -A FORWARD -s $RED_LOCAL -p icmp -j ACCEPT && echo "  FORWARD: icmp (ping), source: $RED_LOCAL"



echo "Aceptando los siguientes puertos en el Router relacionados a servicios:"
## Puertos de los distintos servicios
# Router
iptables -A FORWARD -i $IFACE_OUT -p tcp --dport 22 -j ACCEPT && echo "  FORWARD: 22 (SSH)"
# Servidor Web 192.168.50.3
iptables -A FORWARD -i $IFACE_OUT -p tcp --dport 80 -j ACCEPT && echo "  FORWARD: 80 (HTTP)"
iptables -A FORWARD -i $IFACE_OUT -p tcp --dport 443 -j ACCEPT && echo "  FORWARD: 443 (HTTPS)"
# Servidor DNS 192.168.50.2
iptables -A FORWARD -i $IFACE_OUT -p udp --dport 53 -j ACCEPT && echo "  FORWARD: 53 (udp, DNS)"
iptables -A FORWARD -i $IFACE_OUT -p tcp --dport 8001 -j ACCEPT && echo "  FORWARD: 8001 (HTTP)"
# Servidor Mail 192.168.50.4
iptables -A FORWARD -i $IFACE_OUT -p tcp --dport 25 -j ACCEPT && echo "  FORWARD: 25 (SMTP)"
iptables -A FORWARD -i $IFACE_OUT -p tcp --dport 587 -j ACCEPT && echo "  FORWARD: 587 (SMTP{TLS})"
iptables -A FORWARD -i $IFACE_OUT -p tcp --dport 143 -j ACCEPT && echo "  FORWARD: 143 (IMAP)"
iptables -A FORWARD -i $IFACE_OUT -p tcp --dport 993 -j ACCEPT && echo "  FORWARD: 993 (IMAP{SSL})"
iptables -A FORWARD -i $IFACE_OUT -p tcp --dport 6667 -j ACCEPT && echo "  FORWARD: 6667 (IRC)"
iptables -A FORWARD -i $IFACE_OUT -p tcp --dport 8002 -j ACCEPT && echo "  FORWARD: 8002 (HTTP)"
# Servidor DHCP 192.168.5.91
iptables -A FORWARD -p tcp --dport 631 -j ACCEPT && echo "  FORWARD: 631 (CUPS)"

echo "Habilitando redirecciones a distintos servicios:"
## Redirecciones
# Servidor DNS 192.168.50.2
iptables -t nat -A PREROUTING -i $IFACE_OUT -p tcp --dport 22502 -j DNAT --to $IP_DNS:22502 && echo "  From: $IP_ROUTER:22502 / Redirect To: $IP_DNS:22"
iptables -t nat -A PREROUTING -i $IFACE_OUT -p udp --dport 53 -j DNAT --to $IP_DNS:53 && echo "  From: $IP_ROUTER:53 / Redirect To: $IP_DNS:53"
iptables -t nat -A PREROUTING -i $IFACE_OUT -p tcp --dport 8001 -j DNAT --to $IP_AD:80 && echo "  From: $IP_ROUTER:8001 / Redirect To: $IP_DNS:80"
# Servidor Web 192.168.50.3
iptables -t nat -A PREROUTING -i $IFACE_OUT -p tcp --dport 22503 -j DNAT --to $IP_WEB:22 && echo "  From: $IP_ROUTER:22503 / Redirect To: $IP_WEB:22"
# Servidor Mail 192.168.50.4
iptables -t nat -A PREROUTING -i $IFACE_OUT -p tcp --dport 22504 -j DNAT --to $IP_MAIL:22 && echo "  From: $IP_ROUTER:22504 / Redirect To: $IP_MAIL:22"
iptables -t nat -A PREROUTING -i $IFACE_OUT -p tcp --dport 25 -j DNAT --to $IP_MAIL:25 && echo "  From: $IP_ROUTER:25 / Redirect To: $IP_MAIL:25"
iptables -t nat -A PREROUTING -i $IFACE_OUT -p tcp --dport 587 -j DNAT --to $IP_MAIL:587 && echo "  From: $IP_ROUTER:587 / Redirect To: $IP_MAIL:587"
iptables -t nat -A PREROUTING -i $IFACE_OUT -p tcp --dport 143 -j DNAT --to $IP_MAIL:143 && echo "  From: $IP_ROUTER:143 / Redirect To: $IP_MAIL:143"
iptables -t nat -A PREROUTING -i $IFACE_OUT -p tcp --dport 993 -j DNAT --to $IP_MAIL:993 && echo "  From: $IP_ROUTER:993 / Redirect To: $IP_MAIL:993"
iptables -t nat -A PREROUTING -i $IFACE_OUT -p tcp --dport 8002 -j DNAT --to $IP_MAIL:80 && echo "  From: $IP_ROUTER:8002 / Redirect To: $IP_MAIL:80"
iptables -t nat -A PREROUTING -i $IFACE_OUT -p tcp --dport 6667 -j DNAT --to $IP_CHAT:6667 && echo "  From: $IP_ROUTER:6667 / Redirect To: $IP_CHAT:6667"

echo "Aceptar las conexiones a Internet desde las redes:"
## Acceso desde redes internas a internet
# Red 192.168.5.0/24
iptables -A FORWARD -s $RED_LOCAL -p tcp --dport 80 -j ACCEPT && echo "  FORWARD: 80 (HTTP), source: $RED_LOCAL"
iptables -A FORWARD -s $RED_LOCAL -p tcp --dport 443 -j ACCEPT && echo "  FORWARD: 443 (HTTPS), source: $RED_LOCAL"
iptables -A FORWARD -s $RED_LOCAL -p tcp --dport 21 -j ACCEPT && echo "  FORWARD: 21 (FTP), source: $RED_LOCAL"
iptables -A FORWARD -s $RED_LOCAL -p udp --dport 53 -j ACCEPT && echo "  FORWARD: 53 (DNS), source: $RED_LOCAL"
# Red 192.168.50.0/24
iptables -A FORWARD -s $RED_DMZ -p tcp --dport 80 -j ACCEPT && echo "  FORWARD: 80 (HTTP), source: $RED_DMZ"
iptables -A FORWARD -s $RED_DMZ -p tcp --dport 443 -j ACCEPT && echo "  FORWARD: 443 (HTTPS), source: $RED_DMZ"
iptables -A FORWARD -s $RED_DMZ -p tcp --dport 21 -j ACCEPT && echo "  FORWARD: 21 (FTP), source: $RED_DMZ"
iptables -A FORWARD -s $RED_DMZ -p udp --dport 53 -j ACCEPT && echo "  FORWARD: 53 (DNS), source: $RED_DMZ"

#Activar enrutamiento
iptables -t nat -A POSTROUTING -o enp2s5 -j MASQUERADE
