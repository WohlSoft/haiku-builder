#!/bin/sh

set -exu

# Run a command until it succeeds, to ride out a failed package download. A
# single "Interrupted system call" from pkgman would otherwise fail the build.
retry() {
  attempt=1

  until "$@"; do
    if [ "$attempt" -ge 3 ]; then
      return 1
    fi

    attempt=$((attempt + 1))
    sleep 5
  done
}

install_extra_packages() {
  retry pkgman refresh
  retry pkgman install bash curl rsync -y
}

add_sudo_shim() {
  curl "$PACKER_HTTP_ADDR/resources/sudo" -o /boot/system/non-packaged/bin/sudo
  chmod +x /boot/system/non-packaged/bin/sudo
}

remove_welcome_banner() {
  sed -i '/Welcome to the Haiku shell/d' /boot/system/settings/etc/profile
}

set_hostname() {
  echo 'runnervmg1sw1.local' > /system/settings/network/hostname
}

install_extra_packages
add_sudo_shim
remove_welcome_banner
set_hostname
