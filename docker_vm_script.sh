#!/bin/bash

device_serial="localhost:5555"
suspend_time=${suspend_time:-20}
SECONDS=0
stop=$(($SECONDS+60*$suspend_time))



# For starting the virtual device with a premade container
start_snapshot_container () {
    #/usr/bin/toolbox
    #alias docker-compose='docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "/home/yurigblaise:/home/yurigblaise" -w="/home/yurigblaise" docker/compose:1.24.0'
    #sed -i '/.*emulator_emulator.*/{n;N;N;d}' ./docker/docker-compose-build.yaml
    #sed -i "s|emulator_emulator|blaiseyuri/emu_avd_snapshot_p_x86_64|" ./docker/docker-compose-build.yaml
    #cd js/jwt-provider
    #wget https://bootstrap.pypa.io/pip/3.6/get-pip.py
    #python get-pip.py --user
    #python -m pip install -r requirements.txt
    #cp jwt_secrets_pub.jwks ../docker/certs/jwt_secrets_pub.jwks
    #docker-compose -f ./docker/docker-compose-build.yaml -f  ./docker/development.yaml up -d

    snapshot_image=$1
    curl https://codeload.github.com/google/android-emulator-container-scripts/tar.gz/master  | tar -xz --strip=2 "android-emulator-container-scripts-master/js"
    sed -i '/.*emulator_emulator.*/{n;N;N;d}' ./docker/docker-compose-build.yaml
    sed -i "s/emulator_emulator/${snapshot_image}/" ./docker/docker-compose-build.yaml
    dir=$PWD
    sudo su -l $USER << EOF
    echo $PWD
    sudo chmod 666 /var/run/docker.sock
    docker-compose -f $dir/docker/docker-compose-build.yaml -f  $dir/docker/development.yaml up -d
EOF
}

start_container () {
    sudo su -l $USER << EOF
    echo "STARTING NESTED DOCKER CONTAINER"
    cd ~/android-emulator-container-scripts
    sudo chmod 666 /var/run/docker.sock
    docker-compose -f ~/android-emulator-container-scripts/js/docker/docker-compose-build.yaml -f ~/android-emulator-container-scripts/js/docker/development.yaml up -d
EOF
}

try_adb_connect () {
    SECONDS=0
    adb_connected=false
    until [ "$SECONDS" -gt "$stop" ] || "$adb_connected"; do
        echo "attempting to connect..."
        echo "$((($stop-$SECONDS)/60)) Minutes till restart"
        ! adb connect $device_serial | grep "Connection refused" 
        result_code=$?
        if [ "$result_code" -eq 1 ]; then  
            echo "Adb connection not successful, retying..."
            sleep 5
        else
            adb_connected=true
            echo "Adb connection successful"
        fi
    done
    if [ $SECONDS -gt $stop ]; then
        echo "try_adb_connect has timed out after $SECONDS seconds allotted time was $stop seconds"
        echo "Shutting down..."
        sudo shutdown -h now
    fi
}

docker_push() {
    default_id=$(get_docker_id);
    container_name=$2
    dockerhub_account=$1
    docker login
    docker commit $default_id $container_name
    echo "Commit completed tagging image and pushing"
    docker image tag emulator_emulator "${dockerhub_account}/${container_name}"
    echo "Docker image "${dockerhub_account}/${container_name}" tagged now being pushed"
    docker push ${dockerhub_account}/${container_name}
}

get_docker_id() {
    local docker_name="${1:-emulator}"
    local id;
    until [ ${#id} -gt 0 ] ; do
        sleep 5
        id=$(docker ps -qf name=$docker_name)
        
    done;
    echo $id

}


wait_docker_health () {
    default_id=$(get_docker_id);
    containername="${1:-$default_id}" #get name if null provide id
    sleep 1;
    SECONDS=0
    health_status=$(docker inspect -f {{.State.Health.Status}} $containername)
    echo $health_status
    until [ "`docker inspect -f {{.State.Health.Status}} $containername`"=="healthy" ]; do
        sleep 1;
        echo "Device status is $health_status"
        health_status=$(docker inspect -f {{.State.Health.Status}} $containername)
        echo $health_status
    done;
}

# Save snapshot in container image
save_snapshot() {
    device_serial=${1:-$device_serial}
    default_id=$(get_docker_id)
    echo "Connected to container, saving snapshot"
    docker exec $default_id /android/sdk/platform-tools/adb emu avd snapshot save container_snapshot
    docker exec $default_id /android/sdk/platform-tools/adb emu avd snapshot pull container_snapshot /home/container_snapshot
}

load_snapshot () {
    device_serial=${1:-$device_serial}
    default_id=$(get_docker_id)
    echo "Connected to container, loading snapshot"
    docker exec $default_id /android/sdk/platform-tools/adb emu avd snapshot push container_snapshot /home/container_snapshot
    docker exec $default_id /android/sdk/platform-tools/adb emu avd snapshot load container_snapshot
    docker exec $default_id /android/sdk/platform-tools/adb emu avd snapshot list
}

check_emu_idle () {
    device_serial=${1:-$device_serial}
    idle_time_found=false
    SECONDS=0
    #attempt to get the idle time via adb if not found after stop, shutdown VM
    until [ $SECONDS -gt $stop ] || "$idle_time_found"; do
        idle_time=$(adb -s $device_serial shell dumpsys power | grep -i "lastUserActivityTime=" | grep -i "ms" | grep -oP '(?<=\()[0-9]+')
        result_code=$?
        echo "Result code: $result_code idle_time: $idle_time(ms)"
        if [ "$result_code" -eq "0" ]; then
            echo "Loop should finish"
            idle_time_found=true
        else
            sleep 30
        fi
    done
    if [ $SECONDS -gt $stop ]; then
        echo "the function check_emu_idle has timed out after $SECONDS seconds allotted time was $stop seconds"
        echo "Saving a snapshot then shutting down."
        save_snapshot $device_serial
        echo "Snapshot saved, shutting down..."
        sudo shutdown -h now
    fi
    idle_minutes=$(($idle_time/60000))
    echo "idle time: $idle_minutes minutes"
    if [ "$idle_minutes" -gt "$suspend_time" ]; then
        echo "Maximum idle time of $suspend_time minutes has been reached."
        echo "Saving a snapshot then shutting down."
        save_snapshot $device_serial
        echo "Snapshot saved, shutting down..."
        sudo shutdown -h now
    fi

}

#Function to check if the emulator is idle in intervals
shutdown_on_idle () {
    sleep_time=$(($suspend_time*60))
    while true; do
        check_emu_idle
        sleep $sleep_time
    done
}

device_power_on () {
    device_serial=${1:-$device_serial}
    set -o pipefail
    adb -s $device_serial shell dumpsys connectivity | sed -e '/[0-9] NetworkAgentInfo.*CONNECTED/p' -n;
    while [ $? -ne 0 ]; do
        sleep 5
        echo "waiting on device to power on"
        adb -s $device_serial shell dumpsys connectivity | sed -e '/[0-9] NetworkAgentInfo.*CONNECTED/p' -n;
    done
    echo "Device is now on"
}
# Check if the function exists (bash specific)
if typeset -f "$1" > /dev/null
then
  # call arguments verbatim
  "$@"
  #if only one parameter is passed ignore
else
  # Show a helpful error
  echo "'$1' is not a known function name" >&2
  exit 1
fi

# try_adb_connect
# check_emu_idle