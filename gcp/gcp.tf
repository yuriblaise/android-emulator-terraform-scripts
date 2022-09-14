provider "google" {
  credentials = "${file(var.gcp_credentials)}"
  project = var.gcp_project
  region  = var.gcp_region
}

# resource "null_resource" "init" {
#   #add username to startup script
#    provisioner "local-exec" {
#     command = "awk -i inplace -v line='gcp_user=\"${var.gcp_user}\"' 'NR==1 && $0 != line{print line} 1' ../startup.sh"
#   }
# }

resource "google_compute_firewall" "firewall" {
  name = "gritfy-firewall-externalssh-${local.prefix}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "80","443" ,"8000-9000", "5500-6000"]
  }

  source_ranges = ["0.0.0.0/0"] # Not So Secure. Limit the Source Range
  target_tags   = ["externalssh"]
  
  lifecycle { 
    ignore_changes = all
  }

}

resource "google_compute_firewall" "webserverrule" {
  name = "gritfy-webserver-${local.prefix}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80","443"]
  }

  source_ranges = ["0.0.0.0/0"] # Not So Secure. Limit the Source Range
  target_tags   = ["webserver"]

  lifecycle { 
    ignore_changes = all
  }
}

# We create a public IP address for our google compute instance to utilize
resource "google_compute_address" "static" {
  name = "vm-public-address-${local.prefix}"
  project = var.gcp_project
  region = var.gcp_region
  depends_on = [ google_compute_firewall.firewall ]
  lifecycle { 
    ignore_changes = all
  }
}


resource "google_compute_instance" "dev" {
  name = "devserver-${local.prefix}"
  machine_type = local.instance_type
  zone         = "${var.gcp_region}-a"
  tags         = ["externalssh","webserver"]
  min_cpu_platform          = "Intel Cascade Lake"

  lifecycle {
    ignore_changes        = all
  }

  advanced_machine_features {
    enable_nested_virtualization = true
  }

  boot_disk {
    initialize_params {
      size = 128
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.static.address
    }
  }
  guest_accelerator{
    type = "nvidia-tesla-k80" // Type of GPU attahced
    count = var.gpu_sku ? 1 : 0 // Num of GPU attached
  }

  connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = var.gcp_user
      timeout     = "500s"
      private_key = file(var.gcp_privatekeypath)
    }

  # Ensure firewall rule is provisioned before server, so that SSH and file upload doesn't fail.
  depends_on = [ google_compute_firewall.firewall, google_compute_firewall.webserverrule]

  service_account {
    email  = var.gcp_email
    scopes = ["compute-ro"]
  }
  
  metadata_startup_script = file("../scripts/startup.sh")

  metadata = {
    ssh-keys = "${var.gcp_user}:${file(var.gcp_publickeypath)}",
    gcp_user = "${var.gcp_user}"
  }
}


resource "null_resource" "restart_instance" {
  depends_on=[null_resource.gcp_remote_exec]
  count = var.restart ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOT
        echo ${google_compute_instance.dev.name}
        vm_status=$(gcloud compute instances describe ${google_compute_instance.dev.name} --zone ${google_compute_instance.dev.zone} --format="value(status)")
        echo $vm_status
        if [ "$vm_status" != "RUNNING"  ]; then
          gcloud compute instances start ${google_compute_instance.dev.name} --zone ${google_compute_instance.dev.zone}
          ssh -i ${var.gcp_privatekeypath} ${var.gcp_user}@${google_compute_address.static.address} "cat /var/log/syslog | grep -i 'MetadataScripts'"
        fi
        ssh -o "ServerAliveInterval 60" -o "ServerAliveCountMax 120" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.gcp_privatekeypath} ${var.gcp_user}@${google_compute_address.static.address} "~/vm_scripts/docker_vm_script.sh wait_docker_health"
        result_code=$(ssh -o "ServerAliveInterval 60" -o "ServerAliveCountMax ${var.suspend_time}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.gcp_privatekeypath} ${var.gcp_user}@${google_compute_address.static.address} "~/vm_scripts/docker_vm_script.sh try_adb_connect")
        if [ "$result_code" -eq "0" ]; then
          ${var.adb_path} connect ${google_compute_address.static.address}:5555
        fi
     EOT
  }
}


resource "null_resource" "gcp_file_upload" {
  for_each = fileset("../scripts", "*")
  connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = var.gcp_user
      timeout     = "500s"
      private_key = file(var.gcp_privatekeypath)
    }
  


  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/vm_scripts",
      "mkdir -p /home/${var.gcp_user}/.docker",
      "ls ~/",
    ]
  }

  provisioner "file" {    
        source = "${each.value}"
        destination = "/home/${var.gcp_user}/vm_scripts/${basename(each.value)}"
  }
}

resource "null_resource" "avd_config_upload" {
  depends_on=[null_resource.gcp_file_upload]
  count = var.avd_config != "" ? 1 : 0
  connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = var.gcp_user
      timeout     = "500s"
      private_key = file(var.gcp_privatekeypath)
    }

  provisioner "file" {    
        source = "${var.avd_config}"
        destination = "/tmp/${ basename(var.avd_config) }"
  }
}

resource "null_resource" "docker_push" {
  depends_on=[local.custom_dependencies]
  count = var.dockerpush && var.dockerhub_account != "" ? 1 : 0
  connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = var.gcp_user
      timeout     = "60m"
      private_key = file(var.gcp_privatekeypath)
    }
  provisioner "file" {    
        source = "${var.docker_config}"
        destination = "/home/${var.gcp_user}/.docker/${basename(var.docker_config)}"
  }
  provisioner "remote-exec" {
    inline = ["/bin/bash ~/vm_scripts/docker_vm_script.sh docker_push ${lower(var.dockerhub_account)} ${lower(local.container_name)}"]
  }
}

resource "null_resource" "gcp_remote_exec" {
  depends_on=[null_resource.gcp_file_upload]
  connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = var.gcp_user
      timeout     = "10m"
      private_key = file(var.gcp_privatekeypath)
    }
  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/vm_scripts/*sh",
      "/bin/bash ${var.load_snapshot_image} && ~/vm_scripts/docker_vm_script.sh snapshot_compose ${var.snapshot_image}",
      "/bin/bash ${!var.load_snapshot_image} && ~/vm_scripts/vm_emu_docker_install.sh ${local.script_args}",
      #adds suspend time value to scripts
      "awk -i inplace -v line='suspend_time=${var.suspend_time}' 'NR==1 && $0 != line{print line} 1' ~/vm_scripts/docker_vm_script.sh",
      "/bin/bash ~/vm_scripts/docker_vm_script.sh wait_docker_health",
      "/bin/bash ~/vm_scripts/docker_vm_script.sh try_adb_connect",
      "/bin/bash ~/vm_scripts/docker_vm_script.sh device_power_on",
      "echo 'waiting...'",
      "sleep 90",
      "echo 'waiting...'",
      "sleep 90",
      "echo 'Saving Snapshot...'",
      "/bin/bash ~/vm_scripts/docker_vm_script.sh save_snapshot"
    ]
  }

}



resource "null_resource" "gcp_adb_upload" {
  depends_on=[google_compute_instance.dev]
  count = var.adb_keys != "" ? 1 : 0
    connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = var.gcp_user
      timeout     = "500s"
      private_key = file(var.gcp_privatekeypath)
    }

  provisioner "remote-exec" {
    inline = ["mkdir ~/.android/"]
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.gcp_privatekeypath} ${var.adb_keys}/adbkey ${var.gcp_user}@${google_compute_address.static.address}:~/.android/ && scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.gcp_privatekeypath} ${var.adb_keys}/adbkey.pub ${var.gcp_user}@${google_compute_address.static.address}:~/.android/"
    
  }
}

# download adb_keys after install 
resource "null_resource" "gcp_download_adbkeys" {
  depends_on=[null_resource.gcp_remote_exec]
  count = var.download_adb_keys ? 1 : 0
    connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = var.gcp_user
      timeout     = "500s"
      private_key = file(var.gcp_privatekeypath)
    }

    provisioner "local-exec" {
          command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.gcp_privatekeypath} ${var.gcp_user}@${google_compute_address.static.address}:~/.android/* ${path.cwd}"
    }
}

resource "null_resource" "gcp_adb_connection" {
  depends_on=[null_resource.gcp_remote_exec]
  count = var.adb_connect ? 1 : 0
  connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = var.gcp_user
      timeout     = "500s"
      private_key = file(var.gcp_privatekeypath)
    }

 #after VM adb server is connected attempt to connect to adb locally
  provisioner "local-exec" {
    command ="${var.adb_path} connect ${google_compute_address.static.address}:5555"
  }
}

resource "null_resource" "gcp_destroy_all" {
  count = var.auto_destroy ? 1 : 0
  depends_on=[null_resource.docker_push]
  connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = var.gcp_user
      timeout     = "500s"
      private_key = file(var.gcp_privatekeypath)
    }
  provisioner "local-exec" {
    command = "echo y | terraform destroy -lock=False -auto-approve" 
  }
}

output "vm_ip" {
  value = google_compute_address.static.address
}

output "instance_name" {
  value = google_compute_instance.dev.name
}

output "image_name" {
  value = local.image_reg_alphanum
}

output "image_var" {
  value = var.image_regexp
}

output "container_var" {
  value = var.container_name
}

output "container_name" {
  value = local.container_name
}