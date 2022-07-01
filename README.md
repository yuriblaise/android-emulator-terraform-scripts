# Terraform-android-emulator
Terraform scripts for launching an android emulator docker container in the cloud

## Setup
To successfully run these scripts you will need
* A [GCP Account](https://cloud.google.com/free-trial) 
* [Terraform](https://cloud.google.com/docs/Terraform) v1.1.8 or newer
* [Google CLI Terraform Plugin](registry.Terraform.io/hashicorp/google) v4.26.0 or newer  cli

### Installing Terraform
The instructions for installing terraform can be found [here](https://learn.hashicorp.com/tutorials/terraform/install-cli). The GCP plugin will be installed when `terraform init` is run after install.

Once Terraform and gcloud cli are installed on your system. You can download the Terraform dependencies with the commands.

```sh
cd ./gcp
terraform init
```

## Configuration
To change the instance or container variables edit the `emu_docker_vars.tf` file.

To set the variables needed for the gcloud cli plugin edit the `variables.tf` file.

## Launching the Emulator instance
once the scripts are downloaded the android emulator container scripts can be launched on a GCP instance with

```
terraform apply
```

### Connect automatically
By default, Terraform will spin up a `C2-standard-4` instance with an emulator running Android P (API Level 28). Once the emulator is booted  Terraform will attempt to connect to the cloud emulator with your local adb server. Connecting via the instance public ip address to tcp port 5555.

### Connecting on Windows with WSL2
You can install and launch these scripts with [Windows Subsystem Linux](). Once Terraform is installed on WSL2. You can launch the your instance and connect to it from your Windows host adb server by changing the `adb_keys` and `adb_path` variables to... 

```HCF
variable "adb_keys" {
   description = "path to the folder containing the adb keypair to use with the container and VM"
   type        = string
   default     = "/mnt/c/Users/<windows_username>/.android"
}
variable "adb_path" {
   description = "path of adb executable to use"
   type        = string
   default     = "/mnt/c/Users/<windows_username>/AppData/Local/Android/Sdk/platform-tools/adb.exe" #changed from "adb"
}
```

This assume that adb is installed in the default location on your host. In general as long as the script has access to the local adb keys and executable, the local adb server should be able to connect.


### Upload/Download ADB Keys
If the connection fails you can connect with any adb instance as long as you have the adbkeys and the ip address. By default Terraform will upload your local adb keys and use them for the cloud emulator. For convienence the keys are also downloaded the gcp folder as `adbkey` and `adbkey.pub` by default.

### Restarting the instance
To prevent unexpected charges, the script shuts down the instance after its detected that the emulator has been idle for more than 5 minutes. The allowed idle time duration can be changed with the `suspend_minutes` variable, to disable this feature entirely use `auto_suspend` to false. Before shutting down the instance will save a snapshot, the snapshot will automatically be loaded once the VM is restarted.

To restart the instance after its been shut down use the command

```
terraform apply -replace="null_resource.gcp_restart" -var="restart=true"
```

this will restart the instance and relaunch the emulator with the snapshot loaded.

If the instance has already been restarted once set restart to false and before trying again.

```
terraform apply -replace="null_resource.gcp_restart" -var="restart=false"
```

To tear down the instance use the command

```
terraform destroy
```

### Creating a new instance
Before creating a new instance you will need to destroy your previously made emulator and your snapshots/all other work will be lost.

To destroy an existing instance and create a new one you can use this command. 

```
terraform destroy && terraform apply
```

You can use the `-auto-approve` flag to bypass any terraform prompts.

### Key variables

If the default setup doesn't fit your needs, the script is pretty easily configurable via the `emu_docker_vars.tf` file.

In particular changing the `suspend_time` may be useful.

```HCL
variable "instance_type" {
   description = "cloud provider instance type"
   type        = string
   default     = "c2-standard-4"
}
variable "image_regexp" {
   description = "regexp to select image for docker container"
   type        = string
   default     = "P.*x86_64"
}
variable "adb_keys" {
   description = "path to the folder containing the adb keypair to use with the container and VM"
   type        = string
   default     = "~/.android/"
}
variable "adb_path" {
   description = "path of adb executable to use"
   type        = string
   default     = "adb"
}
variable "auto_suspend" {
  type = bool
  default = true
  description = "Suspend VM after startup"
}
variable "suspend_time" {
  type = number
  default = 5
  description = "Number of minutes to let VM run before suspending"
}
variable "auto_destroy" {
   type = bool
   default = false
   description = "Terraform will destroy all cloud resources after all scripts are done running"
}
```

### To Do
* Pricing Info