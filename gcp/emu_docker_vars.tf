variable "instance_type" {
   description = "cloud provider instance type"
   type        = string
   default     = "c2-standard-4"
}

variable "prefix" {
   description = "Prefix to use for resources"
   type        = string
   default     = ""
}

variable "gpu_sku" {
   description = "whether to attach a GPU"
   type        = bool
   default     = false
}
variable "kvm_on" {
   description = "whether to enable KVM in VM"
   type        = bool
   default     = true
}
variable "launch_command" {
   description = "custom command to launch in VM after install"
   type        = string
   default     = ""
}
variable "adb_connect" {
   description = "Automatically connect to container via adb after emulator is turned on"
   type        = bool
   default     = false
}
variable "adb_keys" {
   description = "path to the folder containing the adb keypair to use with the container and VM"
   type        = string
   default     = "~/.android"
}
variable "adb_path" {
   description = "path of adb executable to use"
   type        = string
   default = "adb"
}
variable "download_adb_keys" {
   description = "download adb keys from the container to the results directory"
   type        = bool
   default     = false
}
variable "image_regexp" {
   description = "regexp to select image for docker container"
   type        = string
   default     = "P.*x86_64"
}
variable "emu_regexp" {
   description = "regexp to select emulator for docker container"
   type        = string
   default     = ""
}
variable "avd_config" {
  type = string
  default = ""
  description = "path to custom config.ini file for avd"
}
variable "avd_props" {
  type = string
  default = ""
  description = "list of comma seperated avd property values formatted as property=value E.g hw.ramSize=2048,disk.dataPartitionsize=512MB"
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

variable "suspend_on_idle" {
  type = bool
  default = false
  description = "Suspend VM after system has been idle for longer than the suspend time"
}

variable "auto_destroy" {
   type = bool
   default = true
   description = "terraform will destroy all cloud resources after the VM has been up"
}

variable "destroy_time" {
   type = number
   default = 30
   description = "Amount of time the VM will run before terraform attempts to destroy all resources"
}

variable "restart" {
   type = bool
   default = false
   description = "Restart the VM"
}

variable "load_snapshot_image" {
   type = bool
   default = true
   description = "Load a prebuilt snapshot of a container instead of building from scratch"
}

variable "dockerpush" {
   type=bool
   default=true
   description="Toggle if the container image should be pushed after snapshot creation"
}

variable "docker_config" {
   type=string
   default="~/.docker/config.json"
   description="Path to docker config json file"
}

variable "dockerhub_account" {
   type=string
   default = ""
   description="Dockerhub account for pushing an image (e.g account/container_name)"
}

variable "snapshot_image" {
   type=string
   default=""
   description="Name of the snapshot image to pull (e.g account/container_name)"
}

variable "container_name" {
   type=string
   default=""
   description="Name of the container to push (e.g account/container_name)"
}

variable "custom_exec" {
   type=list(string)
   default=[]
   description="List of terraform resource names to run before the docker image is pushed"
}