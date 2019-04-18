#!/bin/vbash

############
# Pre-Requisites:
# 1) File at /config/scripts/previous.ip with the WAN IP "previously". This will be compared to the new Dynamic DNS IP.
# 2) "postscript" option for ddclient added to EdgeOS configuration. For example: 'set service dns dynamic interface eth0 service dyndns options postscript=/config/scripts/updatelocaladdress.sh"
############


#Get hostname
HOSTNAME=$(hostname)
currentIp=$1
previousIp=$(cat /config/scripts/previous.ip)

if  [ "$currentIp" == "$previousIp" ]; then
	
	echo "$(date +'%h %e %T')" "Dynamic DNS Update Notification: ${HOSTNAME}'s IP hasn't changed. Keeping current IP as ${currentIp} - doing nothing." >> /var/log/messages

else

	echo "$(date +'%h %e %T')" "Dynamic DNS Update Notification: ${HOSTNAME} has has had its Dynamic IP updated to ${currentIp}. Updating VPN local-address configuration" >> /var/log/messages

	#Get list of VPN peers:
	peers=$(/opt/vyatta/bin/vyatta-op-cmd-wrapper show configuration commands | grep "set vpn ipsec site-to-site" | awk '{print $6}' | sort -u)

	for ip in $peers
	do
	/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper begin
	/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete vpn ipsec site-to-site peer $ip local-address
	/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set vpn ipsec site-to-site peer $ip local-address $currentIp
	/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper commit

	echo "$(date +'%h %e %T')" "Dynamic DNS Update Notification: VPN local-address update complete for peer $ip. Sending Pushover Notification." >> /var/log/messages
	bash /config/scripts/pushover.sh -a monitor -m "Dynamic DNS updated on EdgeRouter $HOSTNAME. New IP $currentIp applied to VPN VTI Local Address for peer $ip"

	done

	echo "$currentIp" > /config/scripts/previous.ip
	
fi

exit 0
