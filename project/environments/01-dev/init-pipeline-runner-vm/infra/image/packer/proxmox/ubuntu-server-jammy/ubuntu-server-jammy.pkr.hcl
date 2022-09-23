/*
Written by: https://github.com/ctalaveraw

This project is for deploying a Packer template on Proxmox.
This VMI (Virtual Machine Image) will be based on Ubuntu 22.04.1 LTS
This is the "Jammy Jellyfish" release and will contain "cloud-init" baked in.
*/

# Variable Definitions
variable "proxmox_api_token_id" {
    type = string
}

variable "proxmox_api_token_secret" {
    type = string
    sensitive = true
}

variable "proxmox_api_url" {
    type = string
}

# VM Template Resource Definition
source "proxmox" "ubuntu-server-jammy" {

    # Proxmox Connection Settings
    username = "${var.proxmox_api_token_id}"
    token = "${var.proxmox_api_token_secret}"
    proxmox_url = "${var.proxmox_api_url}"
    
    # TLS Verification Skip (If needed)
    # insecure_skip_tls_verify = true
    
    # VM General Settings
    node = "tva" # Name of the destination "node" on Proxmox
    vm_id = "100"
    vm_name = "ubuntu-server-jammy"
    template_description = "Ubuntu 22.04.1 LTS Jammy Jellyfish VMI"
    
    # VM ISO source (Choose ONLY ONE)
    
    # Download ISO (Option 1)
    # iso_url = "https://releases.ubuntu.com/22.04/ubuntu-22.04.1-live-server-amd64.iso"
    # iso_checksum = "INSERT_CHECKSUM_HERE"
    
    # Local ISO File (Option 2)
    # iso_file = "local:iso/ubuntu-22.04.1-live-server-amd64.iso"
    
    # VM OS Settings
    iso_storage_pool = "local"
    unmount_iso = true
    
    # VM System Settings
    qemu_agent = true
    
    # VM Hard Disk Settings
    scsi_controller = "virtio-scsi-pci"
    disks {
        disk_size = "20G"
        format = "qcow2"
        storage_pool = "local-lvm"
        storage_pool_type = "lvm"
        type = "virtio"
    }
    
    # VM CPU Settings
    cores = "1"
    
    # VM Memory Settings
    memory = "2048" 
    
    # VM Network Settings
    network_adapters {
        model = "virtio"
        bridge = "vmbr0"
        firewall = "false"
    } 
    
    # VM Cloud-Init Settings
    cloud_init = true
    cloud_init_storage_pool = "local-lvm"
    
    # PACKER Boot Commands
    boot_command = [
        "<esc><wait><esc><wait>",
        "<f6><wait><esc><wait>",
        "<bs><bs><bs><bs><bs>",
        "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ",
        "--- <enter>"
    ]
    boot = "c"
    boot_wait = "5s"
    # PACKER Autoinstall Settings
    http_directory = "http" 
    # (Optional) Bind IP Address and Port
    # http_bind_address = "0.0.0.0"
    # http_port_min = 8802
    # http_port_max = 8802
    ssh_username = "your-user-name"
    # (Option 1) Add your Password here
    # ssh_password = "your-password"
    # - or -
    # (Option 2) Add your Private SSH KEY file here
    # ssh_private_key_file = "~/.ssh/id_rsa"
    # Raise the timeout, when installation takes longer
    ssh_timeout = "20m"
}
# Build Definition to create the VM Template
build {
    name = "ubuntu-server-focal"
    sources = ["source.proxmox.ubuntu-server-focal"]
    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
    provisioner "shell" {
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge",
            "sudo apt -y clean",
            "sudo apt -y autoclean",
            "sudo cloud-init clean",
            "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
            "sudo sync"
        ]
    }
    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
    provisioner "file" {
        source = "files/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }
    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
    provisioner "shell" {
        inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
    }
    # Add additional provisioning scripts here
    # ...
}
