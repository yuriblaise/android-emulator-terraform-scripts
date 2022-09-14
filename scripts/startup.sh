# This assumes that the vm already has the android-docker-container dependencies installed
# via the android-emulator-terraform-scripts
gcp_user=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/gcp_user" -H "Metadata-Flavor: Google")
gcp_user=${gcp_user:-root} #default value will be replaced by terraform variable "gcp_user"
home_dir="/home/$gcp_user"
echo "VM STARTUP SCRIPT IS RUNNING"
cd $home_dirs/android-emulator-container-scripts/

sudo chmod +x -R $home_dir/android-emulator-container-scripts/
sudo su -l $gcp_user <<EOT
# 1. check if there is an existing image
if docker-compose -f $home_dir/android-emulator-container-scripts/js/docker/docker-compose.yaml -f $home_dir/android-emulator-container-scripts/js/docker/development.yaml up ; then
    # 2. if so run the image in developer mode
    echo "Command succeeded"
    /bin/bash $home_dir/vm_scripts/docker_vm_script.sh wait_docker_health
    /bin/bash $home_dir/vm_scripts/docker_vm_script.sh try_adb_connect
    /bin/bash $home_dir/vm_scripts/docker_vm_script.sh device_power_on
    /bin/bash $home_dir/vm_scripts/docker_vm_script.sh load_snapshot
    nohup /bin/bash $home_dir/vm_scripts/docker_vm_script.sh shutdown_on_idle </dev/null &>/dev/null &
    sleep 5

else
    # 3. if not create a new image with emu-docker
    echo "Docker Image not found attempting to create a new one this may take a while..."
    emu-docker create canary "$image_regx" && ./create_web_container.sh -p user1,passwd1 -a
    # 4. Check for backed up snapshot
    # 5. Load snapshot once found.    
fi
EOT
