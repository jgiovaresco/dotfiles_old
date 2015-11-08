#!/bin/bash
set -e

USERNAME=julien
export DEBIAN_FRONTEND=noninteractive

check_is_sudo() {
	if [ "$EUID" -ne 0 ]; then
		echo "Please run as root."
		exit
	fi
}

base_setup() {

	/bin/bash -c "$(wget https://raw.githubusercontent.com/jgiovaresco/dotfiles/laptop/bin/install-base.sh --no-cache -O -) base jessie"

}

# installs packages for a laptop
packages_laptop() {
	apt-get update
	apt-get -y upgrade

	apt-get install -y \
		automake \
		ca-certificates \
		cgroupfs-mount \
		cmake \
		curl \
		dnsutils \
		libnotify-bin \
		network-manager \
		rxvt-unicode-256color \
		scdaemon \
		sudo \
		xclip \
		xcompmgr \
		xz-utils \
		--no-install-recommends

	# install tlp with recommends
	apt-get install -y tlp tlp-rdw
}

setup_sudo() {
	# add user to sudoers
	adduser $USERNAME sudo

	# add user to systemd groups
	gpasswd -a $USERNAME systemd-journal
	gpasswd -a $USERNAME systemd-network

	{ \
		echo -e 'Defaults	secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"'; \
		echo -e 'Defaults	env_keep += "ftp_proxy http_proxy https_proxy no_proxy"'; \
		echo -e "${USERNAME} ALL=(ALL) NOPASSWD:ALL"; \
		echo -e "${USERNAME} ALL=NOPASSWD: /bin/mount, /sbin/mount.nfs, /bin/umount, /sbin/umount.nfs, /sbin/ifconfig, /sbin/ifup, /sbin/ifdown, /sbin/ifquery"; \
	} >> /etc/sudoers
}

configure_main_user() {
	# create subshell
	(
	cd "/home/$USERNAME"

	#
	gpasswd -a $USERNAME downloads
	gpasswd -a $USERNAME multimedia
	gpasswd -a $USERNAME ebooks
	gpasswd -a $USERNAME photos
	gpasswd -a $USERNAME docker

	# fetch oh-my-zsh
	git clone https://github.com/robbyrussell/oh-my-zsh.git .oh-my-zsh
	chsh $USERNAME -s /bin/zsh

	# fetch dotfiles from repo
	git clone -b server https://github.com/jgiovaresco/dotfiles.git dotfiles
	
	# installs all the things
	make

	# enable dbus for the user session
	systemctl --user enable dbus.socket

	sudo systemctl enable i3lock
	sudo systemctl enable suspend-sedation.service

	cd "/home/$USERNAME"

	# install .vim files
	git clone https://github.com/jgiovaresco/.vim.git "/home/$USERNAME/.vim"
	git clone https://github.com/gmarik/vundle.git "/home/$USERNAME/.vim/bundle/vundle"
	ln -s "/home/$USERNAME/.vim/.vimrc" "/home/$USERNAME/.vimrc"
	sudo ln -s "/home/$USERNAME/.vim" /root/.vim
	sudo ln -s "/home/$USERNAME/.vimrc" /root/.vimrc

	echo "To install VIM plugins (ignore potential error messages at the first start)"
	echo "run vim +BundleInstall +qall"
	)
}

configure_motd() {
	sudo chmod +x /etc/update-motd.d/*
	sudo rm /etc/motd
	sudo ln -s /var/run/motd /etc/motd
}

install_network_driver() {

	apt-get install -y firmware-iwlwifi firmware-realtek --no-install-recommends
	modprobe -r iwlwifi ; modprobe iwlwifi

}

install_graphics() {
	
	local pkgs="xorg xserver-xorg xserver-xorg-video-intel"
	apt-get install -y $pkgs --no-install-recommends

}

intsall_audio() {
	local pkgs="alsa-base alsa-utils alsa-tools libasound2"

	apt-get install -y $pkgs --no-install-recommends

	alsactl init
}

install_wm() {
	local pkgs="feh i3 i3lock i3status slim"

	apt-get install -y $pkgs --no-install-recommends

	# add xorg conf
	curl -sSL https://raw.githubusercontent.com/jgiovaresco/dotfiles/laptop/etc/X11/xorg.conf > /etc/X11/xorg.conf

	# pretty fonts
	curl -sSL https://raw.githubusercontent.com/jgiovaresco/dotfiles/laptop/etc/fonts/local.conf > /etc/fonts/local.conf

	echo "Fonts file setup successfully now run:"
	echo "	dpkg-reconfigure fontconfig-config"
	echo "with settings: "
	echo "	Autohinter, Automatic, No."
	echo "Run: "
	echo "	dpkg-reconfigure fontconfig"
}

clean() {

	sudo apt-get autoremove
	sudo apt-get autoclean

}

usage() {
	echo -e "install.sh\n\tThis script installs my basic setup for a debian laptop\n"
	echo "Usage:"
	echo "  all {jessie strech}     	- complete setup"
	echo "  install-packages            - install laptop base pkgs"
	echo "  network                     - install network drivers"
	echo "  graphics                    - install graphics drivers"
	echo "  wm                    		- install window manager / configure desktop"
	echo "  audio                  		- install / configure sound"
	echo "  main-user              		- configure main user"
	echo "  motd                		- configure main user"
}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "all" ]]; then
		check_is_sudo
		echo "----> Base setup"
		base_setup
		echo "----> Install laptop packages"
		packages_laptop
		echo "----> Setup sudo"
		setup_sudo
		echo "----> Configure main user"
		configure_main_user
		echo "----> Configure motd"
		configure_motd
		echo "----> Configure network"
		install_network_driver
		echo "----> Configure graphics"
		install_graphics
		echo "----> Configure audio"
		intsall_audio
		echo "----> Configure WM"
		install_wm
		echo "----> End of setup"
		print_manual_steps
		clean
	elif [[ $cmd == "install-packages" ]]; then
		check_is_sudo
		packages_laptop
		setup_sudo
		clean
	elif [[ $cmd == "network" ]]; then
		check_is_sudo
		install_network_driver
		clean
	elif [[ $cmd == "graphics" ]]; then
		check_is_sudo
		install_graphics
		clean
	elif [[ $cmd == "wm" ]]; then
		check_is_sudo
		install_wm
		clean
	elif [[ $cmd == "audio" ]]; then
		check_is_sudo
		intsall_audio
		clean
	elif [[ $cmd == "main-user" ]]; then
		configure_main_user
		clean
	else
		usage
	fi
}

main "$@"