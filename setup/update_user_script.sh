#!/bin/bash
# save as /root/update_user_script.sh

# update user login.bash
USERINFOFILE=/root/new_docker/user_info
USERINFO=$(cat $USERINFOFILE)
for user in $USERINFO
do
  echo "update $user script..."
  cp /public/login.bash /home/$user/docker-gpu
  echo "done!"
done