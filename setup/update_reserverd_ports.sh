#!/bin/bash
# save as /root/update_reserved_ports.sh

# add reserverd ports for old users
USERINFOFILE=/root/new_docker/user_info
USERINFO=$(cat $USERINFOFILE)
for user in $USERINFO
do
    echo "Update reserved ports: "
    RESERVED_PORTFILE=/public/next-reserved-port
    RESERVED_PORT_1=$(cat $RESERVED_PORTFILE)
    RESERVED_PORT_2=$(( $RESERVED_PORT_1+1 ))
    echo $RESERVED_PORT_1 $RESERVED_PORT_2 > /public/reserved-ports/$user
    echo $(( $RESERVED_PORT_2+1 )) > $RESERVED_PORTFILE
    printf "\e[96;1m$RESERVED_PORT_1 $RESERVED_PORT_2\e[0m\n"
    echo "done!"
done