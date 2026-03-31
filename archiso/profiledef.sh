#!/usr/bin/env bash
# hecatOS ISO profile definition for archiso

iso_name="hecatos"
iso_label="HECATOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="hecatOS <https://hecatos.org>"
iso_application="hecatOS Live/Install"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')

file_permissions=(
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/hecate"]="0:0:440"
  ["/root"]="0:0:750"
  ["/usr/local/bin/hecate-install"]="0:0:755"
  ["/usr/local/bin/hecatos-live-setup"]="0:0:755"
)
