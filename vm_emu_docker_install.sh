#!/bin/bash
# Arguments


image_regx="P.*x86_64"
custom_command=""
kvm_on=${1:-true}
#Function for adding and updating AVD config properties
#if the property isn't found will add it to the file
set_avd() {
    default_config_path="$PWD/emu/templates/config/avd/Pixel2.avd/config.ini"
    config_ini="${2:-$default_config_path}"
    prop_list=$(echo "$1" | tr ',' ' ')
    eval "prop_arr=($prop_list)"
    for arg in "${prop_arr[@]}"
    do
        echo $arg
        #check for proper formatting before setting values
        if [[ $arg == *"="* ]]; then 
            prop_val=(${arg//=/ }) # split string on
            avd_property=${prop_val[0]}
            value=${prop_val[1]}
        else
            echo "$arg property ignored must have a value assigned"
            continue
        fi
        if grep -q "$avd_property" $config_ini 
        then
            echo "$avd_property property found, updating to $value"
            sed -i -e "s/^${avd_property}=.*$/${avd_property}=${value}/g" $config_ini
        else
            echo "adding $avd_property property to avd config file"
            echo "${avd_property}=${value}" >> $config_ini
        fi
    done
}

#takes a avd config ini file and moves to the template dir
avd_config() {
    echo "Updating AVD config file..."
    config_ini=${2:-"$PWD/emu/templates/config/avd/Pixel2.avd/config.ini"}
    cp $1 $config_ini
    echo "done"
} 



cd ~/
# Installing emu-docker dependencies
# sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" -qq --allow upgrade
# printf 2 | sudo apt update -y && sudo apt upgrade -y
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get -yq upgrade
sudo apt install software-properties-common -y
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt install python3-pip -y
sudo apt install python-pip -y
sudo apt install android-tools-adb -y

#installing docker
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt-cache policy docker-ce -y
sudo apt install docker-ce -y
sudo usermod -aG docker ${USER}
sudo chmod 666 /var/run/docker.sock
#Installing docker-compose with curl
VERSION=1.29.2; sudo curl -Lo /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/$VERSION/docker-compose-`uname -s`-`uname -m` && sudo chmod +x /usr/local/bin/docker-compose

#cloning repo and installing emu-docker
git clone https://github.com/google/android-emulator-container-scripts.git  &> /dev/null
cd ~/android-emulator-container-scripts
# After repo is cloned handle arguments
echo "Handling script parameters..."
echo $@
while [[ $# -gt 0 ]]; do
  case $1 in
    -c)
        if [[ $3 != *"-"* && $3 != "" ]]; then
            avd_config $2 $3
            shift 3 # past argument and values
        else
            avd_config $2
            shift 2 # past argument and value
        fi
            ;;
    -s) 
        custom_command=$2
        shift 2
        ;;
    -i) 
        image_regx=$2
        shift 2
        ;;
    -p) # Must be the last argument
        shift #past argument
        set_avd $@ #pass all remaining arguments to set_avd
      ;;
    -k) #kvm_on
        kvm_on=$2
        shift 2
        ;;
    *)
      shift # past argument
      ;;
  esac
done
. ./configure.sh || true # there may be a bug where configure has to be run twice
echo "Repo cloned and configure.sh has been sourced"
if [ "$kvm_on" = false  ]; then
	echo "Disabling KVM Setting"
	cd ~/android-emulator-container-scripts/js/docker
	cp docker-compose-build.yaml placeholder.yaml
	sed '/devices:/d' placeholder.yaml > docker-compose-build.yaml
	rm -rf placeholder.yaml
    cd ~/android-emulator-container-scripts
fi

# Conditional for AVD/ini config should go here
# if there is a avd paramter take the path and
# replace the file with the new config
# if parameters memory, disk, resolution are true do X

sudo apt-get install python3-venv -y

# for docker to work bash has to be reset
sudo su -l $USER << EOF
cd ~/android-emulator-container-scripts
sudo apt install python3.7-venv -y
sudo rm /usr/bin/python3
sudo ln -s python3.7 /usr/bin/python3
sudo apt install python3.7-venv -y
python -m ensurepip --upgrade
adb start-server
. ./configure.sh || true 
echo "STARTING EMU-DOCKER SCRIPT"
emu-docker -h || true
pip install markupsafe==2.0.1 # ensure that the a working version of markup is installed for now
if [ -z "$custom_command" ]; then 
    for i in 1 2 3; do echo y | emu-docker create canary "$image_regx" && break || sleep 15; done
    ./create_web_container.sh -p user1,passwd1 -a
else 
    eval "$custom_command"
fi
docker-compose -f ~/android-emulator-container-scripts/js/docker/docker-compose-build.yaml -f ~/android-emulator-container-scripts/js/docker/development.yaml up -d
exit 0
EOF
exit