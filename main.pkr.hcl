variable "os_version" {
  type = string
  description = "The version of the operating system to download and install"
}

variable "architecture" {
  type = object({
    name = string
    image = string
    qemu = string
  })
  description = "The type of CPU to use when building"
}

variable "machine_type" {
  default = "q35"
  type = string
  description = "The type of machine to use when building"
}

variable "cpu_type" {
  default = "max"
  type = string
  description = "The type of CPU to use when building"
}

variable "memory" {
  default = 8192
  type = number
  description = "The amount of memory to use when building the VM in megabytes"
}

variable "cpus" {
  default = 4
  type = number
  description = "The number of cpus to use when building the VM"
}

variable "disk_size" {
  default = "12G"
  type = string
  description = "The size in bytes of the hard disk of the VM"
}

variable "checksum" {
  type = string
  description = "The checksum for the virtual hard drive file"
}

variable "root_password" {
  default = "vagrant"
  type = string
  description = "The password for the root user"
}

variable "headless" {
  default = false
  description = "When this value is set to `true`, the machine will start without a console"
}

variable "use_default_display" {
  default = true
  type = bool
  description = "If true, do not pass a -display option to qemu, allowing it to choose the default"
}

variable "display" {
  default = "cocoa,zoom-to-fit=off"
  description = "What QEMU -display option to use"
}

variable "acceleration" {
  default = true
  description = "Indicates if hardware acceleration should be enabled or not"
}

variable "qmp_socket" {
  default = ""
  type = string
  description = <<-EOF
    The path of a Unix socket where QEMU should expose a QMP monitor of its own,
    for tooling that inspects the guest while it builds. When empty, no extra
    monitor is opened.
  EOF
}

variable "install_wait" {
  default = "1m"
  type = string
  description = <<-EOF
    How long to wait for the installation to finish. One minute is enough with
    hardware acceleration; a build without it needs considerably longer.
  EOF
}

locals {
  iso_target_extension = "iso"
  iso_target_path = "packer_cache"
  iso_full_target_path = "${local.iso_target_path}/${sha1(var.checksum)}.${local.iso_target_extension}"

  vm_name = "haiku-${var.os_version}-${var.architecture.name}.qcow2"
  iso_path = "${var.os_version}/haiku-${var.os_version}-${var.architecture.image}-anyboot.iso"
}

source "qemu" "qemu" {
  machine_type = var.machine_type
  cpus = var.cpus
  memory = var.memory
  net_device = "e1000"

  disk_compression = true
  disk_interface = "virtio"
  disk_size = var.disk_size
  format = "qcow2"

  headless = var.headless
  use_default_display = var.use_default_display
  display = var.display
  accelerator = "none"
  qemu_binary = "qemu-system-${var.architecture.qemu}"
  cpu_model = var.cpu_type

  ssh_username = "user"
  ssh_password = var.root_password
  ssh_timeout = "10000s"

  qemuargs = concat(
    [
      ["-boot", "strict=off"],
      ["-monitor", "none"],
    ],

    var.acceleration ? [["-accel", "kvm"], ["-accel", "hvf"], ["-accel", "tcg"]] : [],

    var.qmp_socket != "" ? [["-qmp", "unix:${var.qmp_socket},server=on,wait=off"]] : [],

    [
      ["-device", "qemu-xhci"],
      ["-device", "usb-tablet"],
      ["-device", "nec-usb-xhci,id=usb-controller-0"],

      // r1beta6 does not detect virtio-blk disks, and virtio-scsi is what the
      // action boots the resulting image with anyway.
      ["-device", "virtio-scsi-pci"],
      // The vendor string becomes the disk's name, which DriveSetup offers as
      // the name of the volume it formats.
      ["-device", "scsi-hd,drive=drive0,bootindex=0,vendor=Haiku,product="],
      ["-device", "ide-cd,drive=drive1,bootindex=1"],
      ["-drive", "if=none,file={{ .OutputDir }}/{{ .Name }},id=drive0,cache=writeback,discard=ignore,format=qcow2"],
      ["-drive", "if=none,file=${local.iso_full_target_path},id=drive1,media=disk,format=raw,readonly=on"],
    ],
  )

  iso_checksum = var.checksum
  iso_target_extension = local.iso_target_extension
  iso_target_path = local.iso_target_path
  iso_urls = [
    "http://mirror.rit.edu/haiku/${local.iso_path}",
    "https://ftp.osuosl.org/pub/haiku/${local.iso_path}",
    "https://s3.us-east-1.wasabisys.com/haiku-release/${local.iso_path}",
    "https://cloudflare-ipfs.com/ipns/hpkg.haiku-os.org/release/${local.iso_path}",
    "https://mirror.aarnet.edu.au/pub/haiku/${local.iso_path}",
  ]

  http_directory = "."
  output_directory = "output"
  shutdown_command = "shutdown -q"
  vm_name = local.vm_name

  boot_wait = "40s"

  boot_steps = [
    // Installer
    ["<tab><wait>", "Keymap"],
    ["<tab><wait>", "Select 'Install Haiku'"],
    ["<spacebar><wait15s>", "Press 'Install Haiku'"],

    ["<enter><wait5s>", "Continue"],

    ["<enter><wait5s>", "No parations have been found ..."],

    ["<tab><wait>", "Install from"],
    ["<tab><wait>", "Onto"],
    ["<tab><wait>", "Show optional packages"],
    ["<tab><wait>", "Select 'Set up partions'"],
    ["<spacebar><wait20s>", "Press 'Set up partions'"],

    // DriveSetup
    // The list opens with nothing selected, and the first <down> lands on
    // either the first or the second row, depending on whether the list has
    // taken focus yet. The selection stops at the last row instead of wrapping
    // around, so pressing down more times than the list has rows always ends
    // up on the disk, which sorts after the DVD that was booted from.
    [
      "<down><down><down><down><down><down><wait>",
      "Select '/dev/disk/scsi/1/0/0/raw'"
    ],
    ["<leftAltOn><esc><leftAltOff><wait>", "open main menu"],
    ["<right><wait>", "Partition"],
    ["<down><wait>", "Select 'Format'"],
    ["<right><wait>", "Open 'Format'"],

    /*["<down><wait>", "NT File System"],
    ["<down><wait>", "Select 'Be File System'"],*/
    ["<spacebar><wait>", "Press 'Be File System'"],

    ["<tab><wait>", "Select Continue"],
    ["<spacebar><wait5s>", "Press Continue"],

    ["<enter><wait5s>", "Format"],

    // Are you sure you want to write the changes back to disk now?
    ["<tab><wait>", "Select 'Write changes'"],
    ["<spacebar><wait15s>", "Press 'Write changes'"],

    // The partion "Haiku" has been successfully formatted.
    ["<enter><wait5s>", "OK"],

    // DriveSetup
    ["<leftAltOn>w<leftAltOff><wait10s>", "Close"],

    // Installer
    ["<leftShiftOn><tab><leftShiftOff><wait>", "Show optional packages"],
    ["<leftShiftOn><tab><leftShiftOff><wait>", "Select 'Onto'"],
    ["<down><wait>", "Open 'Onto'"],
    ["<up><wait>", "Select '/dev/disk/scsi/1/0/0/raw'"],
    ["<enter><wait>", "Press '/dev/disk/scsi/1/0/0/raw'"],
    ["<enter><wait${var.install_wait}>", "Begin"],
    ["<enter>", "Restart"],
    ["<wait2m>", "Wait for restart"],

    // Haiku. System is now installed and has rebooted. Need to set password.
    ["haiku<enter>", "Haiku"],
    ["system<enter><wait5s>", "Change to 'system' directory"],
    ["apps<enter><wait5s>", "Change to 'apps' directory"],
    ["Terminal<enter><wait5s>", "Start 'Terminal', application"],
    ["passwd<enter><wait>", "Execute 'passwd' command"],
    ["${var.root_password}<enter><wait>", "Set password"],
    ["${var.root_password}<enter><wait>", "Confirm set password"],

    // Configure SSH
    [
      "echo 'PermitRootLogin yes' >> /system/settings/ssh/sshd_config<enter><wait>",
      "Enable SSH login for root user"
    ],
    [
      "echo 'PermitEmptyPasswords yes' >> /system/settings/ssh/sshd_config<enter><wait>",
      "Allow empty password"
    ],
    [
      "echo 'ForceCommand /boot/home/ssh_shell.sh' >> /system/settings/ssh/sshd_config<enter><wait>",
      "Enable SSH login for root user"
    ],
    [
      "curl 'http://{{.HTTPIP}}:{{.HTTPPort}}/resources/ssh_shell.sh' -o /boot/home/ssh_shell.sh && chmod +x /boot/home/ssh_shell.sh<enter><wait>",
      "Copy SSH command wrapper"
    ],
    // Quit the terminal
    ["exit<enter><wait>", "Exit Terminal"],

    // Restart SSH daemon
    ["<leftAltOn>w<leftAltOff><wait>", "Close 'apps' window"],
    ["preferences<enter><wait5s>", "Change to 'preferences' directory"],
    ["network<enter><wait5s>", "Open Network preferences"],
    ["<tab><wait>", "Select left side list"],
    ["<down>", "IPv4"],
    ["<down>", "IPv6"],
    ["<down>", "Services"],
    ["<down>", "DNS Settings"],
    ["<down>", "FTP server"],
    ["<down>", "Hostname settings"],
    ["<down><wait>", "SSH server"],
    ["<tab><wait>", "Move focus to 'Disable' button"],
    ["<spacebar><wait5s>", "Click Disable"],
    ["<spacebar>", "Click Enable"]
  ]
}

packer {
  required_plugins {
    qemu = {
      version = "~> 1.1.1"
      source = "github.com/hashicorp/qemu"
    }
  }
}

build {
  sources = ["qemu.qemu"]

  provisioner "shell" {
    script = "resources/provision.sh"
  }

  provisioner "shell" {
    script = "resources/custom.sh"
  }

  provisioner "shell" {
    script = "resources/cleanup.sh"
  }
}
