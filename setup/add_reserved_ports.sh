#!/bin/bash
# save as /root/new_docker/add_reserved_ports.sh

### add user
USERNAME=$1
if [[ -z "$USERNAME" ]]; then
    echo "Please give me a username"
    exit 1
fi

# allocate reserved port
printf "Allocating reserved ports: "
RESERVED_PORTFILE=/public/next-reserved-port
RESERVED_PORT_1=$(cat $RESERVED_PORTFILE)
RESERVED_PORT_2=$(( $RESERVED_PORT_1+1 ))
echo $RESERVED_PORT_1 $RESERVED_PORT_2 > /public/reserved-ports/$USERNAME
echo $(( $RESERVED_PORT_2+1 )) > $RESERVED_PORTFILE
printf "\e[96;1m$RESERVED_PORT_1 $RESERVED_PORT_2\e[0m\n"

# info
RPORT_1=$(cat /public/reserved-ports/$USERNAME | awk '{print $1}')
RPORT_2=$(cat /public/reserved-ports/$USERNAME | awk '{print $2}')
printf "  Your allocated reserved ports: \e[96;1m$RPORT_1 $RPORT_2\e[0m, please use on demand.\n"