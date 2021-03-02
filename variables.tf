variable "pm_api_url" {
  type        = string
  default     = "https://proxmox.local:8006/api2/json"
  description = "Proxmox api url"
}

variable "pm_user" {
  type        = string
  default     = "root@pam"
  description = "PM User Proxmox"
}

variable "pm_ssh_user" {
  type        = string
  default     = "root"
  description = "PM User Proxmox"
}

variable "pm_ssh_password" {
  type        = string
  default     = "test"
  description = "PM Password Proxmox"
}

variable "pm_ssh_host" {
  type        = string
  default     = "proxmox.local"
  description = "PM Password Proxmox"
}

variable "pm_tls_insecure" {
  type        = bool
  default     = false
  description = "Insecure TLS Proxmox"
}

variable "target_node" {
  type        = string
  default     = "proxmox"
  description = "Target Proxmox Node"
}

variable "sync_manifests" {
  type        = bool
  default     = true
  description = "If true, terraform will copy the contents of the `manifests` directory in the repo to /var/lib/rancher/k3s/server/manifestsi - ssh-agent required"
}

variable "k3s_args" {
  type        = list
  default     = []
  description = "Additional k3s args (kube-proxy, kubelet, and controller args also go here"
}

variable "ssh_keys" {
  type        = list
  default     = []
  description = "SSH Keys to inject into nodes"
}

variable "ssh_private_key" {
  type        = string
  default     = "~/.ssh/id_rsa"
  description = "SSH Keys to inject into nodes"
}

variable "data_sources" {
  type        = list
  default     = ["cdrom"]
  description = "data sources for node"
}

variable "kernel_modules" {
  type        = list
  default     = []
  description = "kernel modules for node"
}

variable "sysctls" {
  type        = list
  default     = []
  description = "sysctl params for node"
}

variable "dns_nameservers" {
  type        = list
  default     = ["8.8.8.8", "1.1.1.1"]
  description = "kernel modules for node"
}

variable "ntp_servers" {
  type        = list
  default     = ["0.us.pool.ntp.org", "1.us.pool.ntp.org"]
  description = "ntp servers"
}

variable "clone_template_name" {
  type        = string
  default     = "k3os-template"
  description = "Template to use for k3s agent instances"
}

variable "master_node_count" {
  type        = number
  default     = 1
  description = "Number of server nodes to launch"
}

variable "worker_node_count" {
  type        = number
  default     = 3
  description = "Number of agent nodes to launch"
}

#TODO: Randomly Generate this if undefined
variable "k3s_cluster_secret" {
  default     = "abcdef12345"
  type        = string
  description = "Override to set k3s cluster registration secret - This will be made random at default"
}
