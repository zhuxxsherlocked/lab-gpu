#!/bin/bash
# author zhuxx
# save as /public/login.bash
# chmod a+x /public/login.bash

IP=`/sbin/ifconfig enp2s0 | grep "inet" |awk 'NR==1{print $2}'`
# notice: HDD PATH
# GPU01: /data GPU03: /mnt
if [ $IP == "10.10.49.174" ]; then
    HDD_PATH="/data"
else
    HDD_PATH="/mnt"
fi

CONTAINER_NAME="$USER-container"
SNAPSHOT_PATH="$HDD_PATH/Workspaces/container-snapshot"
PORT=$(cat /public/ports/$USER)
RESERVED_PORT_1=$(cat /public/reserved-ports/$USER | awk '{print $1}')
RESERVED_PORT_2=$(cat /public/reserved-ports/$USER | awk '{print $2}')


function print_tip {
    echo "========== Tips:"
    printf "  HDD mounted at \e[96;1m$HDD_PATH\e[0m\n"
    printf "  HOME directory mounted at \e[96;1m/home/$USER\e[0m\n"
    printf "  See GPU load: \e[96;1mnvidia-smi\e[0m\n"
    docker port $CONTAINER_NAME | grep 180* > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        printf "  Your allocated reserved ports: \e[96;1m$RESERVED_PORT_1 $RESERVED_PORT_2\e[0m.  The ports have already been mapped: \e[96;1mhost:$RESERVED_PORT_1 => container:$RESERVED_PORT_1\e[0m, \e[96;1mhost:$RESERVED_PORT_2 => container:$RESERVED_PORT_2\e[0m.\n"
    fi
    printf "  More detailed guide: \e[96;1;4mhttps://www.yuque.com/docs/share/31492f84-9dc9-4741-9da4-f71f4cca6f6a?#\e[0m\n"
    echo "========== "
}

function print_command_help {
    echo "========== Container Operation Menu:"
    printf "  * Login your container, please input \e[96;1mlogin\e[0m\n"
    printf "  * Stop your container, please input \e[96;1mstop\e[0m\n"
    printf "  * Restart your container, please input \e[96;1mrestart\e[0m\n"
    printf "  * Take a snapshot, please input \e[96;1msnapshot\e[0m\n"
    echo 
}

function container_info {
    echo "========== Your Container Information:"
    Name=`docker inspect --format '{{.Name}}' ${CONTAINER_NAME}`
    Pid=`docker inspect --format '{{.State.Pid}}' ${CONTAINER_NAME}`
    Status=`docker inspect --format '{{.State.Status}}' ${CONTAINER_NAME}`
    IPAddress=`docker inspect --format '{{.NetworkSettings.IPAddress}}' ${CONTAINER_NAME}`
    echo "Name:    ${Name:1}"
    echo "Pid:     $Pid"
    echo "Status:  $Status"
    echo "IP:      $IPAddress"
}

function auto_register {
    docker inspect --format '{{.State.Running}}' $CONTAINER_NAME > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "========== This is the first time you login to the server, creating your container now..."
        # nvidia-docker run -dit -v /home/$USER:/home/$USER -v /data:/data -p$PORT:22 --name=$CONTAINER_NAME -h="$USER-VM" cuda-conda-desktop:1.0
        nvidia-docker run -dit -v /home/$USER:/home/$USER -v $HDD_PATH:/data -p$PORT:22 -p$RESERVED_PORT_1:$RESERVED_PORT_1 -p$RESERVED_PORT_2:$RESERVED_PORT_2  --name=$CONTAINER_NAME -h="$USER-VM" cuda-conda-desktop:1.0

        if [ $? -ne 0 ]; then
            echo "========== Fail. Please contact administrators"
            exit 1
        fi
        sleep 2  # wait 2 seconds for container running
    fi
}

function do_login {
    IF_RUNNING=`docker inspect --format '{{.State.Running}}' ${CONTAINER_NAME}`
    if [ "${IF_RUNNING}" != "true" ]; then
        echo "========== It seems that your container is not running"
        echo "========== Starting your container..."
        docker start ${CONTAINER_NAME}
        if [ $? -ne 0 ]; then
            echo "========== Fail. Please contact administrators"
            exit 1
        fi
    fi
    echo "========== Your container is running"

    container_info

    echo "========== Logining your container..."
    ssh -X root@localhost -p $PORT
}

function do_stop {
    echo "========== Stopping your container..."
    docker stop ${CONTAINER_NAME}
    container_info
}

function do_restart {
    echo "========== Restarting your container..."
    docker restart ${CONTAINER_NAME}
    container_info
}

function do_snapshot {
    echo "========== Take a snapshot of your container..."
    SAVETO=$SNAPSHOT_PATH/$USER.tar
    docker export -o ${SAVETO} ${CONTAINER_NAME}
    if [ -f "$SAVETO" ]; then
        printf "========== Successfully saved to: \e[96;1m$SAVETO\e[0m\n"
        printf "========== Please save to your computer in time if necessary\n"
        printf "========== The copy on the server will be processed irregularly\n"
        du -sh $SAVETO
    fi
}

# function recover {
#     echo "========== Recover from a snapshot..."
#     RECOVERFROM=$SNAPSHOT_PATH/$USER.tar
#     if [ ! -f "$RECOVERFROM" ]; then
#         echo "========== Snapshot does not exists."
#         echo "========== Please take a snapshot first."
#         return
#     fi

#     echo "========== WARNING: If you want to recover from your snapshot, fisrtly will delete your previous container"
#     echo "Please input \e[96;1myes\e[0m\n to confirm"
#     read RECOVER_OPTION
#     if   [ "$RECOVER_OPTION" != "yes" ]; then
#         echo "Recover cancelled"
#         return
#     fi

#     docker rm -f $CONTAINER_NAME
# }


printf "========== Hi, \e[96;1m$USER\e[0m\n"
echo "========== Welcome to Our Lab GPU Server (IP: $IP)"

if [[ -z "$PORT" ]]; then
    echo "Failed to get your allocated port."
    echo "If this problem cannot be solved by retrying, please contact administrators."
    exit 1
fi

auto_register
print_tip
print_command_help
echo "Please input your command:"
read COMMAND
if   [ "$COMMAND" == "login" ];   then do_login
elif   [ "$COMMAND" == "stop" ];    then do_stop
elif   [ "$COMMAND" == "restart" ];    then do_restart
elif   [ "$COMMAND" == "snapshot" ];    then do_snapshot
else
    echo "========== Unknown command"
    print_command_help
    exit 1
fi
echo "========== Have a good day :-)"