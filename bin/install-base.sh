#!/bin/bash
set -e

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
		bridge-utils \
		bzip2 \
		cgroupfs-mount \
		coreutils \
		curl \
		file \
		findutils \
		git \
		gcc \
		gnupg \
		gnupg-agent \
		gnupg-curl \
		grep \
		gzip \
		hostname \
		less \
		libc6-dev \
		libltdl-dev \
		libtinfo5 \
		libtinfo-dev \
		libncurses5 \
		libncurses5-dev \
		locales \
		lsof \
		make \
		mount \
		ncurses-bin \
		net-tools \
		nfs-common \
		p7zip \
		ssh \
		tar \
		tree \
		tzdata \
		unzip \
		vim \
		zip \
		zsh \
		--no-install-recommends
	
	create_groups
}

create_groups() {

	groupadd --force --gid 1001 multimedia
	groupadd --force --gid 1002 downloads
	groupadd --force --gid 1006 ebooks
	groupadd --force --gid 1007 photos

}

configure_zsh_for_root() {

	git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
	cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc

}

configure_motd() {
	mkdir -p /etc/update-motd.d

	curl -sSL https://raw.githubusercontent.com/jgiovaresco/dotfiles/master/etc/update-motd.d/00-header  > /etc/update-motd.d/00-header
	curl -sSL https://raw.githubusercontent.com/jgiovaresco/dotfiles/master/etc/update-motd.d/10-sysinfo > /etc/update-motd.d/10-sysinfo
	curl -sSL https://raw.githubusercontent.com/jgiovaresco/dotfiles/master/etc/update-motd.d/90-footer  > /etc/update-motd.d/90-footer

	chmod +x /etc/update-motd.d/*
	rm /etc/motd
	ln -s /var/run/motd /etc/motd
}

install_base_application() {

	# Install progress (https://github.com/Xfennec/progress.git)
	git clone https://github.com/Xfennec/progress.git /tmp/progress
	cd /tmp/progress
	make && make install

	# Docker
}

# installs docker master
# and adds necessary items to boot params
install_docker() {
	# create docker group
	groupadd --force --gid 132 docker

	curl -sSL https://get.docker.com/builds/Linux/x86_64/docker-latest > /usr/bin/docker
	chmod +x /usr/bin/docker

	# systemd-docker
	curl -sSL https://github.com/ibuildthecloud/systemd-docker/releases/download/v0.2.1/systemd-docker > /usr/bin/systemd-docker
	chmod +x /usr/bin/systemd-docker

	curl -sSL https://raw.githubusercontent.com/jgiovaresco/dotfiles/master/etc/systemd/system/docker.service  > /etc/systemd/system/docker.service
	curl -sSL https://raw.githubusercontent.com/jgiovaresco/dotfiles/master/etc/systemd/system/docker.socket   > /etc/systemd/system/docker.socket
	curl -sSL https://raw.githubusercontent.com/jgiovaresco/dotfiles/master/etc/systemd/system/dnsdock.service > /etc/systemd/system/dnsdock.service

	systemctl daemon-reload
	systemctl enable docker

	# update grub with docker configs and power-saving items
	sed -i.bak 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"/g' /etc/default/grub
	echo "Docker has been installed. If you want memory management & swap"
	echo "run update-grub & reboot"
}

usage() {
	echo -e "install-base.sh\n\tThis script installs my basic setup for my computers\n"
	echo "Usage:"
	echo "  base {jessie strech}     	- base installation"
	echo "  sources {jessie strech}     - setup sources following given distribution & install base pkgs"
	echo "  base-package                - install base packages"
	echo "  zsh-root                    - install ZSH for root"
	echo "  appli 	                   	- install base applications"
}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "base" ]]; then
		check_is_sudo
		echo "----> Setup sources"
		setup_sources "$2"
		echo "----> Install base packages"
		base
		echo "----> Configure ZSH for root"
		configure_zsh_for_root
		echo "----> Install base application"
		install_base_application
	elif [[ $cmd == "sources" ]]; then
		setup_sources "$2"
	elif [[ $cmd == "base-package" ]]; then
		base
	elif [[ $cmd == "zsh-root" ]]; then
		configure_zsh_for_root
	elif [[ $cmd == "appli" ]]; then
		install_base_application
	else
		usage
	fi
}

main "$@"