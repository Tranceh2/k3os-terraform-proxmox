terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "2.6.7"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.pm_api_url
  pm_user = var.pm_user
  pm_tls_insecure = var.pm_tls_insecure
}

resource "null_resource" "cloud_init_config_files_master" {
  count = var.master_node_count
  connection {
    type     = "ssh"
    user     = var.pm_ssh_user
    password = var.pm_ssh_password
    host     = var.pm_ssh_host
  }

  provisioner "file" {
    content = templatefile("${path.root}/files/meta-data.tmpl", { instance-name = "k3os-master-${count.index}" })
    destination = "/var/lib/vz/snippets/meta-data"
  }

  provisioner "file" {
    content = templatefile("${path.root}/files/user_data_master.tmpl", { ssh_keys = var.ssh_keys, data_sources = var.data_sources, kernel_modules = var.kernel_modules, sysctls = var.sysctls, dns_nameservers = var.dns_nameservers, ntp_servers = var.ntp_servers, k3s_cluster_secret = var.k3s_cluster_secret, k3s_args = var.k3s_args })
    destination = "/var/lib/vz/snippets/user-data"
  }

  provisioner "remote-exec" {
    inline = [
      "ln -f /var/lib/vz/snippets/user-data /var/lib/vz/snippets/config"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "genisoimage -output /var/lib/vz/template/iso/cloud-init-k3os-master-${count.index}.iso -volid cidata -joliet -rock /var/lib/vz/snippets/config /var/lib/vz/snippets/user-data /var/lib/vz/snippets/meta-data"
    ]
  }
}

resource "proxmox_vm_qemu" "k3os-master" {
  count = var.master_node_count
  depends_on = [
    null_resource.cloud_init_config_files_master,
  ]
  name = "k3os-master"
  desc = "k3os-master"
  agent = 1
  target_node = var.target_node
  clone = var.clone_template_name
  pool = "K3OS"
  bootdisk = "scsi0"
  scsihw   = "virtio-scsi-pci"
  full_clone = true
  define_connection_info = true
  disk {
    type = "scsi"
    storage = "local-lvm"
    size = "10G"
  }
  disk {
    type = "scsi"
    media = "cdrom"
    storage = "local"
    size = "366K"
    volume = "local:iso/cloud-init-k3os-master-${count.index}.iso"
  }
  cores = 2
  sockets = 1
  memory = 2560
  network {
    model = "virtio"
    bridge = "vmbr0"
  }
  os_type = "cloud-init"
  ipconfig0 = "ip=dhcp"
}

resource "null_resource" "k3os_master" {
  count = var.sync_manifests ? 1 : 0
  depends_on = [
    null_resource.cloud_init_config_files,
    proxmox_vm_qemu.k3os-master
  ]

  provisioner "file" {
    source      = "${path.module}/manifests"
    destination = "/home/rancher/"
    connection {
      type  = "ssh"
      host  = proxmox_vm_qemu.k3os-master[0].ssh_host
      private_key = file(var.ssh_private_key)
      user  = "rancher"
      script_path = "/home/rancher/terraform.sh"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 20",
      "sudo mv /home/rancher/manifests/* /var/lib/rancher/k3s/server/manifests/",
      "sudo chown -R root:root /var/lib/rancher/k3s/server/manifests/",
      "sudo chmod -R 0600 /var/lib/rancher/k3s/server/manifests/",
      "sudo cp /etc/rancher/k3s/k3s.yaml /home/rancher/",
      "sudo chown rancher:rancher /home/rancher/k3s.yaml"
    ]
    connection {
      type        = "ssh"
      host        = proxmox_vm_qemu.k3os-master[0].ssh_host
      private_key = file(var.ssh_private_key)
      user        = "rancher"
      script_path = "/home/rancher/terraform.sh"
    }
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null rancher@${proxmox_vm_qemu.k3os-master[0].ssh_host}:~/k3s.yaml kubeconfig && sed -i 's/127.0.0.1/${proxmox_vm_qemu.k3os-master[0].ssh_host}/g' kubeconfig"
  }

  provisioner "remote-exec" {
    inline = [
      "rm /home/rancher/k3s.yaml"
    ]
    connection {
      type        = "ssh"
      host        = proxmox_vm_qemu.k3os-master[0].ssh_host
      private_key = file(var.ssh_private_key)
      user        = "rancher"
      script_path = "/home/rancher/terraform.sh"
    }
  }
}

resource "null_resource" "cloud_init_config_files" {
  count = var.worker_node_count
  connection {
    type     = "ssh"
    user     = var.pm_ssh_user
    password = var.pm_ssh_password
    host     = var.pm_ssh_host
  }

  provisioner "file" {
    content = templatefile("${path.root}/files/meta-data.tmpl", { instance-name = "k3os-worker-${count.index}" })
    destination = "/var/lib/vz/snippets/meta-data"
  }

  provisioner "file" {
    content = templatefile("${path.root}/files/user_data_worker.tmpl", { ssh_keys = var.ssh_keys, data_sources = var.data_sources, kernel_modules = var.kernel_modules, sysctls = var.sysctls, dns_nameservers = var.dns_nameservers, ntp_servers = var.ntp_servers, k3s_cluster_secret = var.k3s_cluster_secret, k3s_server_ip = proxmox_vm_qemu.k3os-master[0].ssh_host })
    destination = "/var/lib/vz/snippets/user-data"
  }

  provisioner "remote-exec" {
    inline = [
      "ln -f /var/lib/vz/snippets/user-data /var/lib/vz/snippets/config"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "genisoimage -output /var/lib/vz/template/iso/cloud-init-k3os-worker-${count.index}.iso -volid cidata -joliet -rock /var/lib/vz/snippets/config /var/lib/vz/snippets/user-data /var/lib/vz/snippets/meta-data"
    ]
  }
}

resource "proxmox_vm_qemu" "k3os-worker" {
  count = var.worker_node_count
  depends_on = [
    null_resource.cloud_init_config_files,
    proxmox_vm_qemu.k3os-master
  ]
  name = "k3os-worker-${count.index + 1}"
  desc = "k3os-worker-${count.index + 1}"
  agent = 1
  target_node = var.target_node
  clone = var.clone_template_name
  pool = "K3OS"
  bootdisk = "scsi0"
  scsihw   = "virtio-scsi-pci"
  full_clone = true
  define_connection_info = true
  disk {
    type = "scsi"
    storage = "local-lvm"
    size = "10G"
  }
  disk {
    type = "scsi"
    media = "cdrom"
    storage = "local"
    size = "366K"
    volume = "local:iso/cloud-init-k3os-worker-${count.index}.iso"
  }
  cores = 2
  sockets = 1
  memory = 2560
  network {
    model = "virtio"
    bridge = "vmbr0"
  }
  os_type = "cloud-init"
  ipconfig0 = "ip=dhcp"
}
