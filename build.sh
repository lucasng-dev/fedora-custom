#!/bin/bash
set -eux -o pipefail

# system info
rpm -qa | grep -E '^kernel-' | sort
cat /etc/os-release
gnome-shell --version

# remove unused repos
rm -f /etc/yum.repos.d/{rpmfusion-*,_copr:*}.repo

# enable rpm fusion repos: https://rpmfusion.org/Configuration
dnf install -y \
	"https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
	"https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf config-manager setopt fedora-cisco-openh264.enabled=1
dnf install -y 'rpmfusion-*-appstream-data'

# install rpm fusion multimedia packages: https://rpmfusion.org/Howto/Multimedia
dnf swap -y ffmpeg-free ffmpeg --allowerasing
for cmd in install update; do
	dnf "$cmd" -y @multimedia --setopt='install_weak_deps=False' --exclude='PackageKit-gstreamer-plugin'
done
dnf install -y intel-media-driver
dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
dnf install -y rpmfusion-free-release-tainted
dnf install -y libdvdcss
dnf install -y rpmfusion-nonfree-release-tainted
dnf --repo='rpmfusion-nonfree-tainted' install -y '*-firmware'

# install rpm packages
dnf install -y \
	langpacks-{en,pt} \
	zsh `#eza` bat micro mc \
	lsb_release fzf fd-find ripgrep tree ncdu tldr bc rsync tmux \
	btop htop nvtop inxi lshw lm_sensors xclip xsel wl-clipboard expect \
	sshuttle tailscale curl wget net-tools telnet traceroute bind-utils mtr nmap netcat tcpdump openssl \
	whois iperf3 speedtest-cli wireguard-tools firewall-config syncthing rclone{,-browser} \
	bsdtar zstd p7zip{,-plugins} zip unzip unrar unar sqlite \
	cmatrix lolcat fastfetch onefetch \
	git{,-lfs,-delta} gh direnv jq yq stow java-openjdk \
	distrobox podman{,-compose,-docker,-tui} \
	gparted parted btrbk duperemove trash-cli \
	cups-pdf gnome-themes-extra gnome-tweaks tilix{,-nautilus} ffmpegthumbnailer \
	openrgb steam-devices \
	execstack \
	onedrive python3-{requests,pyside6} \
	1password-cli insync{,-nautilus} \
	https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
dnf remove -y \
	gnome-software-fedora-langpacks gnome-terminal ptyxis
dnf autoremove -y
find /etc/ -type f -name '*.rpmnew' -delete

# install config files from ublue: https://github.com/ublue-os/packages
git clone --depth=1 https://github.com/ublue-os/packages.git ublue-packages
cp -a ublue-packages/packages/ublue-os-update-services/src/etc/rpm-ostreed.conf /etc/
cp -a ublue-packages/packages/ublue-os-update-services/src/usr/lib/systemd/system/rpm-ostreed-automatic.* /usr/lib/systemd/system/
cp -a ublue-packages/packages/ublue-os-update-services/src/usr/lib/systemd/system/flatpak-system-update.* /usr/lib/systemd/system/
cp -a ublue-packages/packages/ublue-os-update-services/src/usr/lib/systemd/user/flatpak-user-update.* /usr/lib/systemd/user/
sed -Ei 's|[^;&]*\bflatpak\b[^;&]+\brepair\b[^;&]*| /usr/bin/true |g' /usr/lib/systemd/{system,user}/flatpak-*-update.service

# enable update services
systemctl enable rpm-ostreed-automatic.timer
systemctl enable flatpak-system-update.timer
systemctl --global enable flatpak-user-update.timer

# disable gnome-software update service (already managed by previous services)
grep -ERl '^Exec.*\bgnome-software\b' /etc/xdg/autostart /usr/share/dbus-1/services | xargs rm -f
grep -ERl '^Exec.*\bgnome-software\b' /usr/share/applications | xargs sed -Ei '/^DBusActivatable/d'

# configure flatpak repos
systemctl disable flatpak-add-fedora-repos.service
curl -fsSL -o /etc/flatpak/remotes.d/flathub.flatpakrepo https://flathub.org/repo/flathub.flatpakrepo

# enable podman service
systemctl enable podman.socket
systemctl --global enable podman.socket
sed -Ei 's/(--filter\b)/--filter restart-policy=unless-stopped \1/g' /usr/lib/systemd/system/podman-restart.service
systemctl enable podman-restart.service
systemctl --global enable podman-restart.service

# disable ssh service by default
systemctl disable sshd.service

# enable tailscale service
systemctl enable tailscaled.service

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

# install eza from github releases
curl -fsSL -o eza.tar.gz https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz
mkdir eza && bsdtar -xof eza.tar.gz -C eza
mv eza/eza /usr/bin/eza
chmod +x /usr/bin/eza
eza --version

# install fira-code nerd font from github releases
curl -fsSL -o fira-code.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
mkdir fira-code && bsdtar -xof fira-code.zip -C fira-code
mkdir -p /usr/share/fonts/nerd-fonts/fira-code
mv fira-code/*.ttf /usr/share/fonts/nerd-fonts/fira-code/
fc-cache -f

# install starship from github releases
curl -fsSL -o starship.tar.gz https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz
mkdir starship && bsdtar -xof starship.tar.gz -C starship
mv starship/starship /usr/bin/starship
chmod +x /usr/bin/starship
starship --version

# install cloudflared from github releases
curl -fsSL -o /usr/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /usr/bin/cloudflared
cloudflared --version

# install mise from github releases
curl -fsSL https://api.github.com/repos/jdx/mise/releases/latest | jq -r '.assets[].browser_download_url' |
	grep -E '/mise-[^/]+-linux-x64$' | head -n1 | xargs curl -fsSL -o /usr/bin/mise
chmod +x /usr/bin/mise
mise --version

# install onedrive-gui from github sources
curl -fsSL https://api.github.com/repos/bpozdena/OneDriveGUI/releases/latest | jq -r '.tarball_url' |
	xargs curl -fsSL -o onedrive-gui.tar.gz
mkdir onedrive-gui && bsdtar -xof onedrive-gui.tar.gz -C onedrive-gui --strip-components=1
mv onedrive-gui/src /usr/lib/OneDriveGUI

# install warsaw: https://seg.bb.com.br/duvidas.html?question=10
curl -fsSL -o warsaw.run https://cloud.gastecnologia.com.br/bb/downloads/ws/fedora/warsaw_setup64.run
mkdir warsaw && bsdtar -xof warsaw.run -C warsaw --strip-components=1
dnf install -y warsaw/warsaw-*.x86_64.rpm
sed -Ei 's|/var/run/|/run/|g' /usr/lib/systemd/system/warsaw.service
# shellcheck disable=SC2016
sed -E -e 's/multi-user.target/default.target/g' -e 's|/run/|%t/|g' \
	-e 's|^(ExecStart=.*)$|ExecCondition=/bin/sh -c ''[ "$(/bin/id -u)" != "0" ]''\nExecStartPre=/bin/sleep 15\n\1|g' \
	/usr/lib/systemd/system/warsaw.service >/usr/lib/systemd/user/warsaw.service
systemctl enable warsaw.service
systemctl --global enable warsaw.service
tee /usr/lib/tmpfiles.d/zz-warsaw.conf <<-'EOF'
	R /var/usrlocal/*/warsaw - - - - -
	C+ /var/usrlocal/bin/warsaw - - - - /usr/lib/usrlocal/bin/warsaw
	C+ /var/usrlocal/lib/warsaw - - - - /usr/lib/usrlocal/lib/warsaw
	C+ /var/usrlocal/etc/warsaw - - - - /usr/lib/usrlocal/etc/warsaw
EOF
execstack -s /usr/local/bin/warsaw/core # https://aur.archlinux.org/packages/warsaw-bin#comment-1014000

# install canon printer drivers: https://tw.canon/en/support/0101230101
curl -fsSL -o canon.tar.gz https://gdlp01.c-wss.com/gds/1/0100012301/02/cnijfilter2-6.80-1-rpm.tar.gz
echo '55d807ef696053a3ae4f5bb7dd99d063d240bb13c95081806ed5ea3e81464876 canon.tar.gz' | sha256sum -c -
mkdir canon && bsdtar -xof canon.tar.gz -C canon --strip-components=1
dnf install -y canon/packages/cnijfilter2-*.x86_64.rpm

# disable 3rd party repos
sed -Ei '/^enabled=/c\enabled=0' /etc/yum.repos.d/{1password,insync,tailscale}.repo
