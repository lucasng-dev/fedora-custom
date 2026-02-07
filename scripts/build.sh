#!/bin/bash
set -eux -o pipefail

# system info
rpm -qa | grep -E '^kernel-' | sort
cat /etc/os-release
gnome-shell --version

# remove unused repos
rm -vf /etc/yum.repos.d/{rpmfusion-*,_copr:*}.repo

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
# dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
# dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
dnf install -y rpmfusion-free-release-tainted
dnf install -y libdvdcss
dnf install -y rpmfusion-nonfree-release-tainted
dnf --repo='rpmfusion-nonfree-tainted' install -y '*-firmware'

# pre-install (1password): https://github.com/bsherman/ublue-custom/blob/main/build_files/1password.sh
groupadd -g 1790 onepassword
groupadd -g 1791 onepassword-cli

# install rpm packages
dnf install -y --allowerasing \
	langpacks-{en,pt} \
	@virtualization \
	zsh eza bat less micro{,-default-editor} nano vim neovim mc \
	lsb_release fzf fd-find ripgrep tree ncdu tldr bc rsync tmux screen \
	btop htop nvtop inxi lshw lm_sensors xclip xsel wl-clipboard expect \
	openssl curl wget net-tools telnet traceroute bind-utils mtr nmap netcat tcpdump \
	whois iperf3 speedtest-cli wireguard-tools firewall-config \
	bsdtar zstd p7zip{,-plugins} zip unzip unrar unar squashfs-tools sqlite \
	cmatrix lolcat fastfetch onefetch starship topgrade \
	distrobox podman docker{,-compose} \
	git{,-credential-manager,-lfs,-delta,-filter-repo,-extras} gh lazygit jq yq stow \
	ShellCheck shfmt direnv mise \
	kernel-{devel,headers} gcc{,-c++} {,c}make just autoconf automake meson ninja bison m4 patch texinfo \
	nodejs{,-npm} yarnpkg pnpm deno bun-bin \
	python3{,-pip} java-devel dotnet-sdk-10.0 golang rust{,up,-src,fmt,-analyzer} cargo clippy \
	android-tools scrcpy code zed{,-cli} \
	gparted parted btrbk snapper btrfs-assistant duperemove trash-cli \
	cups-pdf gnome-themes-extra gnome-tweaks tilix{,-nautilus} ffmpegthumbnailer sushi \
	dconf-editor file-roller{,-nautilus} gnome-text-editor gnome-firmware seahorse \
	openrgb steam-devices sshuttle syncthing samba \
	onedrive python3-{requests,pyside6} \
	ms-core-fonts firacode-nerd-fonts \
	google-chrome-stable brave-browser 1password{,-cli}
dnf remove -y \
	gnome-software-fedora-langpacks gnome-terminal ptyxis firefox

# install config files from ublue: https://github.com/ublue-os/packages
git clone --depth=1 https://github.com/ublue-os/packages.git ublue-packages
find ublue-packages/packages -type f -name '*.spec' -delete
cp -va ublue-packages/packages/ublue-os-update-services/src/. /

# install veracrypt from github releases
curl -fsSL https://api.github.com/repos/veracrypt/VeraCrypt/releases/latest | jq -r '.assets[].browser_download_url' |
	grep -Ei '/veracrypt-[^/]+-fedora-[^/]+-x86_64.rpm$' | grep -Eiv 'console' | head -n1 | xargs dnf install -y

# install onedrive-gui from github sources
curl -fsSL https://api.github.com/repos/bpozdena/OneDriveGUI/releases/latest | jq -r '.tarball_url' |
	xargs curl -fsSL -o onedrive-gui.tar.gz
mkdir onedrive-gui && bsdtar -xof onedrive-gui.tar.gz -C onedrive-gui --strip-components=1
mv -v onedrive-gui/src /usr/lib/OneDriveGUI

# install canon printer drivers: https://tw.canon/en/support/0101230101
curl -fsSL -o canon.tar.gz https://gdlp01.c-wss.com/gds/1/0100012301/02/cnijfilter2-6.80-1-rpm.tar.gz
echo '55d807ef696053a3ae4f5bb7dd99d063d240bb13c95081806ed5ea3e81464876 canon.tar.gz' | sha256sum -c -
mkdir canon && bsdtar -xof canon.tar.gz -C canon --strip-components=1
dnf install -y canon/packages/cnijfilter2-*.x86_64.rpm

# install warsaw: https://seg.bb.com.br/duvidas.html?question=10
curl -fsSL -o warsaw.run https://cloud.gastecnologia.com.br/bb/downloads/ws/fedora/warsaw_setup64.run
mkdir warsaw && bsdtar -xof warsaw.run -C warsaw --strip-components=1
echo '%_pkgverify_level none' >/etc/rpm/macros.verify # https://bugzilla.redhat.com/show_bug.cgi?id=1830347#c15
dnf install -y warsaw/warsaw-*.x86_64.rpm
rm -vf /etc/rpm/macros.verify
sed -Ei -e 's@/var/run/@/run/@g' -e 's@^ExecStart=(.*)$@ExecStart=/bin/bash -c "exec \1"@g' \
	/usr/lib/systemd/system/warsaw.service
# shellcheck disable=SC2016
sed -E -e 's/multi-user.target/graphical-session.target/g' -e '/^\[Unit\]/a\ConditionUser=!@system' -e 's@/run/@%t/@g' \
	/usr/lib/systemd/system/warsaw.service >/usr/lib/systemd/user/warsaw.service
systemctl enable warsaw.service
systemctl --global enable warsaw.service
# https://aur.archlinux.org/packages/warsaw-bin#comment-1014000
dnf install -y execstack && execstack -s /usr/local/bin/warsaw/core

# enable update services
systemctl enable rpm-ostreed-automatic.timer
systemctl enable flatpak-system-update.timer
systemctl --global enable flatpak-user-update.timer

# disable gnome-software update services (already managed by previous services)
grep -ERl '^Exec.*\bgnome-software\b' /etc/xdg/autostart/ /usr/share/dbus-1/services/ /usr/lib/systemd/user/ | xargs rm -vf
grep -ERl '^Exec.*\bgnome-software\b' /usr/share/applications/ | xargs sed -Ei '/^DBusActivatable/d'

# disable fedora flatpak repos
systemctl disable flatpak-add-fedora-repos.service

# enable container services
systemctl enable docker.service
systemctl enable podman.socket
systemctl --global enable podman.socket
systemctl enable podman-restart.service
systemctl --global enable podman-restart.service

# enable ssh services
systemctl enable sshd.service

# enable virtualization services
systemctl enable libvirtd.service

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

# disable 3rd party repos
sed -Ei '/^enabled=/c\enabled=0' /etc/yum.repos.d/{terra,google-chrome,brave-browser,1password,vscode}.repo

# post-install (1password)
rm -vf /usr/lib/sysusers.d/*onepassword*.conf &>/dev/null || true
echo 'g onepassword 1790' >/usr/lib/sysusers.d/onepassword.conf
echo 'g onepassword-cli 1791' >/usr/lib/sysusers.d/onepassword-cli.conf

# post-install
ln -vsrT /usr/bin/bison /usr/bin/yacc
