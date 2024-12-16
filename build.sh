#!/bin/bash
set -eux -o pipefail
cd "$(mktemp -d)"

# build-time '/var'
mkdir -p /var/{cache,lib,log,tmp,home,roothome}
# persistent '/var'
mkdir -p /usr/lib/alternatives && ln -srfT /usr/lib/alternatives /var/lib/alternatives
mkdir -p /usr/lib/vagrant && ln -srfT /usr/lib/vagrant /var/lib/vagrant
mkdir -p /usr/share/rpm && ln -srfT /usr/share/rpm /var/lib/rpm
# persistent '/var' (requires 'rootfs/usr/lib/tmpfiles.d/zz-persist.conf')
mkdir -p /usr/lib/opt && ln -srfT /usr/lib/opt /var/opt
mkdir -p /usr/lib/usrlocal && ln -srfT /usr/lib/usrlocal /var/usrlocal

# rpm packages
dnf install -y --enablerepo=rpmfusion-nonfree-steam \
	langpacks-{en,pt} \
	zsh eza bat micro mc \
	lsb_release fzf fd-find ripgrep tree ncdu tldr bc rsync tmux \
	btop htop nvtop inxi lm_sensors xclip xsel wl-clipboard \
	openssl curl wget net-tools telnet traceroute mtr bind-utils mtr nmap netcat whois \
	iperf3 speedtest-cli wireguard-tools firewall-config syncthing \
	p7zip{,-plugins} zip unzip unrar unar cabextract \
	cmatrix lolcat fastfetch onefetch \
	git{,-lfs,-delta} gh direnv jq yq \
	distrobox podman{,-compose,-docker,-tui} \
	gparted parted btrbk duperemove \
	cups-pdf gnome-themes-extra gnome-tweaks tilix{,-nautilus} \
	openrgb steam-devices \
	onedrive python3-{requests,pyside6} \
	tailscale 1password-cli \
	https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
dnf remove -y \
	gnome-software-fedora-langpacks firefox gnome-terminal ptyxis
dnf autoremove -y
sed -Ei '/^enabled=/c\enabled=0' /etc/yum.repos.d/{tailscale,1password}.repo

# ublue config files
git clone --depth=1 https://github.com/ublue-os/config.git ublue-config
cp -a ublue-config/files/etc/rpm-ostreed.conf /etc/
cp -a ublue-config/files/etc/systemd/system/rpm-ostreed-automatic.* /etc/systemd/system/
cp -a ublue-config/files/usr/lib/systemd/system/flatpak-system-update.* /usr/lib/systemd/system/
cp -a ublue-config/files/usr/lib/systemd/user/flatpak-user-update.* /usr/lib/systemd/user/
sed -Ei 's|[^;&]*\bflatpak\b[^;&]+\brepair\b[^;&]*| /usr/bin/true |g' /usr/lib/systemd/{system/flatpak-system,user/flatpak-user}-update.service

# enable rpm-ostree update service
systemctl enable rpm-ostreed-automatic.timer

# configure flatpak repos
systemctl disable flatpak-add-fedora-repos.service
wget -qO /etc/flatpak/remotes.d/flathub.flatpakrepo https://flathub.org/repo/flathub.flatpakrepo

# enable flatpak update service
systemctl enable flatpak-system-update.timer
systemctl --global enable flatpak-user-update.timer

# disable gnome-software update service (already managed by previous services)
grep -ERl '^Exec.*\bgnome-software\b' /etc/xdg/autostart /usr/share/dbus-1/services | xargs rm -f
grep -ERl '^Exec.*\bgnome-software\b' /usr/share/applications | xargs sed -Ei '/^DBusActivatable/d'

# enable podman service
systemctl enable podman.socket
systemctl --global enable podman.socket
sed -Ei 's/(--filter\b)/--filter restart-policy=unless-stopped \1/g' /usr/lib/systemd/system/podman-restart.service
systemctl enable podman-restart.service
systemctl --global enable podman-restart.service

# disable sshd service by default
systemctl disable sshd.service

# enable tailscale service
systemctl enable tailscaled.service

# configure udisks2 from example config file
udisks2_generate() { ({ set +x; } &>/dev/null && echo "$(grep -Eo "\b$1=.+" /etc/udisks2/mount_options.conf.example | tail -n 1),$2"); }
cat >/etc/udisks2/mount_options.conf <<-EOF
	[defaults]
	$(udisks2_generate 'ntfs_defaults' 'dmask=0022,fmask=0133,noatime')
	$(udisks2_generate 'exfat_defaults' 'dmask=0022,fmask=0133,noatime')
	$(udisks2_generate 'vfat_defaults' 'dmask=0022,fmask=0133,noatime')
EOF

# configure gnome-disk-image-mounter to mount writable by default
sed -Ei 's/(^Exec=.*\bgnome-disk-image-mounter\b)/\1 --writable/g' /usr/share/applications/gnome-disk-image-mounter.desktop

# install fira-code nerd font from github releases
wget -qO FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
mkdir -p /usr/share/fonts/nerd-fonts
unzip -qoC FiraCode.zip '*.ttf' -d /usr/share/fonts/nerd-fonts/fira-code
fc-cache -f

# install cloudflared from github releases
wget -qO /usr/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /usr/bin/cloudflared
cloudflared --version

# install starship from github releases
wget -qO starship.tar.gz https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz
tar -xzf starship.tar.gz --wildcards 'starship' && mv starship /usr/bin/starship
chmod +x /usr/bin/starship
starship --version

# install mise from github releases
wget -qO- https://api.github.com/repos/jdx/mise/releases/latest | jq -r '.assets[].browser_download_url' |
	grep -E '/mise-[^/]+-linux-x64$' | head -n 1 | xargs wget -qO /usr/bin/mise
chmod +x /usr/bin/mise
mise --version

# install onedrive-gui from github sources
wget -qO- https://api.github.com/repos/bpozdena/OneDriveGUI/releases/latest | jq -r '.tarball_url' |
	xargs wget -qO OneDriveGUI.tar.gz
tar -xzf OneDriveGUI.tar.gz
mv ./*-OneDriveGUI-*/src /usr/lib/OneDriveGUI
