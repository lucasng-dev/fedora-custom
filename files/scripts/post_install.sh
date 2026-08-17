#!/usr/bin/env bash
set -eux -o pipefail

# install insync
dnf install -y \
	"https://dl.insynchq.com/linux/desktop/fedora/$(rpm -E %fedora)" \
	'https://dl.insynchq.com/linux/nautilus/rpm'
sed -Ei 's|(os\.path\.realpath.*)|\1.replace("/var/home/", "/home/")|g' /usr/share/nautilus-python/extensions/insync-nautilus-plugin.py

# install onedrive-gui
curl -fsSL https://api.github.com/repos/bpozdena/OneDriveGUI/releases/latest | jq -r '.tarball_url' |
	xargs curl -fsSL -o onedrive-gui.tar.gz
mkdir onedrive-gui && bsdtar -xof onedrive-gui.tar.gz -C onedrive-gui --strip-components=1
mv onedrive-gui/src /usr/lib/OneDriveGUI

# install minikube
dnf install -y https://storage.googleapis.com/minikube/releases/latest/minikube-latest.x86_64.rpm

# install winboat
curl -fsSL https://api.github.com/repos/TibixDev/winboat/releases/latest | jq -r '.assets[].browser_download_url' |
	grep -Ei '/winboat-[^/]+-x86_64\.rpm$' | head -n1 | xargs dnf install -y

# install canon printer drivers: https://tw.canon/en/support/0101230101
curl -fsSL -o canon.tar.gz https://gdlp01.c-wss.com/gds/1/0100012301/02/cnijfilter2-6.80-1-rpm.tar.gz
echo '55d807ef696053a3ae4f5bb7dd99d063d240bb13c95081806ed5ea3e81464876 canon.tar.gz' | sha256sum -c -
mkdir canon && bsdtar -xof canon.tar.gz -C canon --strip-components=1
dnf install -y canon/packages/cnijfilter2-*.x86_64.rpm

# disable gnome-software update services
grep -ERl '^Exec.*\bgnome-software\b' /etc/xdg/autostart/ /usr/share/dbus-1/services/ /usr/lib/systemd/user/ | xargs rm -vf
grep -ERl '^Exec.*\bgnome-software\b' /usr/share/applications/ | xargs sed -Ei '/^DBusActivatable/d'

# configure udisks2 from example config file
udisks2_generate() { ({ set +x; } &>/dev/null && echo "$(grep -Eo "\b$1=.+" /etc/udisks2/mount_options.conf.example | tail -n1),$2"); }
tee /etc/udisks2/mount_options.conf <<-EOF
	[defaults]
	$(udisks2_generate 'ntfs_defaults' 'dmask=0022,fmask=0133,noatime')
	$(udisks2_generate 'exfat_defaults' 'dmask=0022,fmask=0133,noatime')
	$(udisks2_generate 'vfat_defaults' 'dmask=0022,fmask=0133,noatime')
EOF

# configure gnome-disk-image-mounter to mount writable by default
sed -Ei 's/(^Exec=.*\bgnome-disk-image-mounter\b)/\1 --writable/g' /usr/share/applications/gnome-disk-image-mounter.desktop

# post-install (docker)
rm -vf /usr/lib/sysusers.d/*docker*.conf /usr/lib/sysusers.d/*moby*.conf 2>/dev/null || true
tee /usr/lib/sysusers.d/docker.conf <<-'EOF'
	g docker 913
EOF
ln -vsrT /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose || true

# post-install (1password)
rm -vf /usr/lib/sysusers.d/*1password*.conf /usr/lib/sysusers.d/*onepassword*.conf 2>/dev/null || true
tee /usr/lib/sysusers.d/1password.conf <<-'EOF'
	g onepassword 1790
	g onepassword-cli 1791
	g onepassword-mcp 1792
EOF

# post-install
ln -vsrT /usr/bin/bison /usr/bin/yacc
