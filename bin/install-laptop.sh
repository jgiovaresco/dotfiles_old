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

# sets up apt sources
setup_sources() {
	local dist=$1

	if [[ -z "$dist" ]]; then
		echo "You need to specify a distribution"
		exit 1
	fi


	apt-get install -y apt-transport-https

	cat <<-EOF > /etc/apt/sources.list
	deb http://ftp.fr.debian.org/debian/ 		$dist 			main contrib non-free
	deb-src http://ftp.fr.debian.org/debian/	$dist 			main contrib non-free

	deb http://ftp.fr.debian.org/debian/ 		jessie-backports 	main contrib non-free
	deb-src http://ftp.fr.debian.org/debian/	jessie-backports 	main contrib non-free
	
	deb http://ftp.fr.debian.org/debian/ 		$dist-updates 	main contrib non-free
	deb-src http://ftp.fr.debian.org/debian/	$dist-updates 	main contrib non-free
	
	deb http://security.debian.org/ 			$dist/updates 	main contrib non-free
	deb-src http://security.debian.org/ 		$dist/updates 	main contrib non-free
	
	# tlp: Advanced Linux Power Management
	# http://linrunner.de/en/tlp/docs/tlp-linux-advanced-power-management.html
	deb http://repo.linrunner.de/debian 		sid 			main
	EOF


	# add the tlp apt-repo gpg key
	apt-key adv --keyserver pool.sks-keyservers.net --recv-keys CD4E8809

	# turn off translations, speed up apt-get update
	mkdir -p /etc/apt/apt.conf.d
	echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99translations
}

# installs base packages
base() {
	apt-get update
	apt-get -y upgrade

	apt-get install -y \
		automake \
		bridge-utils \
		bzip2 \
		ca-certificates \
		cgroupfs-mount \
		cmake \
		coreutils \
		curl \
		dnsutils \
		file \
		findutils \
		git \
		gnupg \
		gnupg-agent \
		gnupg-curl \
		grep \
		gzip \
		hostname \
		less \
		libc6-dev \
		libltdl-dev \
		libnotify-bin \
		locales \
		lsof \
		make \
		mount \
		net-tools \
		nfs-common \
		network-manager \
		p7zip \
		rxvt-unicode-256color \
		scdaemon \
		ssh \
		sudo \
		tar \
		tree \
		tzdata \
		unzip \
		vcsh \
		xclip \
		xcompmgr \
		xz-utils \
		zip \
		zsh \
		--no-install-recommends

	# install tlp with recommends
	apt-get install -y tlp tlp-rdw

	configure_zsh_for_root
}

configure_zsh_for_root() {
	git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
	cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc

}

install_network_driver() {

	apt-get install -y firmware-iwlwifi firmware-realtek --no-install-recommends
	modprobe -r iwlwifi ; modprobe iwlwifi

}

install_graphics() {
	
	local pkgs="xorg xserver-xorg xserver-xorg-video-intel"
	apt-get install -y $pkgs --no-install-recommends

}

install_wm() {
	local pkgs="feh i3 i3lock i3status slim"

	apt-get install -y $pkgs --no-install-recommends

	# add xorg conf
	curl -sSL https://raw.githubusercontent.com/jfrazelle/dotfiles/master/etc/X11/xorg.conf > /etc/X11/xorg.conf

	# pretty fonts
	curl -sSL https://raw.githubusercontent.com/jfrazelle/dotfiles/master/etc/fonts/local.conf > /etc/fonts/local.conf

	echo "Fonts file setup successfully now run:"
	echo "	dpkg-reconfigure fontconfig-config"
	echo "with settings: "
	echo "	Autohinter, Automatic, No."
	echo "Run: "
	echo "	dpkg-reconfigure fontconfig"
}

install_sound() {
	local pkgs="alsa-base alsa-utils alsa-tools libasound2"

	apt-get install -y $pkgs --no-install-recommends

	alsactl init
}

clean() {

	sudo apt-get autoremove
	sudo apt-get autoclean

}

usage() {
	echo -e "install.sh\n\tThis script installs my basic setup for a debian laptop\n"
	echo "Usage:"
	echo "  sources {jessie strech}     - setup sources following given distribution & install base pkgs"
	echo "  network                     - install network drivers"
	echo "  graphics                    - install graphics drivers"
	echo "  wm                    		- install window manager / configure desktop"
	echo "  sound                  		- install / configure sound"
	echo "  main_user              		- configure main user"
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

get_dotfiles() {
	# create subshell
	(
	cd "/home/$USERNAME"

	# install oh-my-zsh
	git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
	sudo chsh $USERNAME -s /bin/zsh

	# install dotfiles from repo
	git clone https://github.com/jgiovaresco/dotfiles.git "/home/$USERNAME/dotfiles"
	cd "/home/$USERNAME/dotfiles"

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

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "sources" ]]; then
		check_is_sudo
		setup_sources "$2"
		base
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
	elif [[ $cmd == "sound" ]]; then
		check_is_sudo
		install_sound
		clean
	elif [[ $cmd == "main_user" ]]; then
		get_dotfiles
		clean
	else
		usage
	fi
}

main "$@"