#!/bin/bash
# save as /root/new_docker/new-nvidia-docker-user.sh

GROUPNAME="lab-gpu"

### add user
USERNAME=$1
if [[ -z "$USERNAME" ]]; then
    echo "Please give me a username"
    exit 1
fi
id -u $USERNAME > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "User $USERNAME already exist"
    exit 1
fi

# create user
# temporary password is 123456
echo "Creating user..."
useradd -m -G docker,lab-gpu -g lab-gpu -p WjBvLfnOeZocg $USERNAME


# allocate ssh port
printf "Allocating ssh port: "
PORTFILE=/public/next-port
PORT=$(cat $PORTFILE)
echo $PORT > /public/ports/$USERNAME
echo $(( $PORT+1 )) > $PORTFILE
printf "\e[96;1m$PORT\e[0m\n"

# change password
echo "Setting password in the host:"
passwd $USERNAME

mkdir /home/$USERNAME/docker-gpu
cp /public/login.bash /home/$USERNAME/docker-gpu

# fix filesystem permission
echo "Fixing filesystem permission..."
chown -R $USERNAME:$GROUPNAME /home/$USERNAME/docker-gpu
chmod a+x /home/$USERNAME/docker-gpu/login.bash

# add to user_info
echo "Adding user info..."
USERINFOFILE=/root/new_docker/user_info
sed -i '$a\'$USERNAME'' $USERINFOFILE

# finish
usermod -s /bin/bash $USERNAME
echo "Done!"
printf "Have a good day!"