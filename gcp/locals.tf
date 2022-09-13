    locals {  
        region= "westus2"
        # filepaths for uploading to VM
        docker_vm_script = "../docker_vm_script.sh"
        emu_docker_install_script = "../vm_emu_docker_install.sh"
        files = var.avd_config != "" ? toset([local.emu_docker_install_script, local.docker_vm_script, var.avd_config]) : toset([local.emu_docker_install_script, local.docker_vm_script])
        #results_dir scp remote_exec
        #instance_num is a block property
        #gpu_sku adds a block for gcp

        #Handling variables for local and remote execution
        #VM variables kvm_on image_regexp emu_regexp
        # If kvm_on false add argument to launch_command
        # image_regxp add as argument
        # emulator_regexp (experimental)
        #launch_command disable script launch and replace with new command
        #adb will need to open a port if true
        instance_type = var.instance_type
        prefix =  substr(uuid(),0,8)
        command = var.launch_command != "" ? "-s ${var.launch_command}" : ""
        image_regexp = "-i ${var.image_regexp}"
        image_reg_alphanum = replace(replace(var.image_regexp, "/[^a-zA-Z0-9]/"," "), "/\\s+/", "_") # parse image regex to use for container name
        container_name = var.container_name != "" ? var.container_name : "emu_avd_snapshot_${local.image_reg_alphanum}"
        kvm_on = "-k ${var.kvm_on}"
        config = var.avd_config != "" ? "-c /tmp/${ basename(var.avd_config)}" : ""
        props = var.avd_props != "" ? "-p ${var.avd_props}" : ""
        script_args = "${local.image_regexp} ${local.kvm_on} ${local.command} ${local.config} ${local.props}"
        local_config = var.avd_config != "" ? "-c ${var.avd_config}" : ""
        gpu = 0
    }
