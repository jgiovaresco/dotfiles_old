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

	/bin/bash -c "$(wget https://raw.githubusercontent.com/jgiovaresco/dotfiles/server/bin/install-base.sh --no-cache -O -) base jessie"

}

# installs packages for a server
packages_server() {
	apt-get update
	apt-get -y upgrade

	apt-get install -y \
		cups \
		figlet \
		nfs-kernel-server \
		samba \
		sane \
		--no-install-recommends
}

clean() {

	apt-get autoremove
	apt-get autoclean

}

# installs docker master
# and adds necessary items to boot params
install_docker() {
	# create docker group
	groupadd --force --gid 132 docker
	gpasswd -a $USERNAME docker

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

configure_main_user() {
	# create subshell
	(
	cd "/home/$USERNAME"

	#
	gpasswd -a $USERNAME downloads
	gpasswd -a $USERNAME multimedia
	gpasswd -a $USERNAME ebooks
	gpasswd -a $USERNAME photos

	# fetch oh-my-zsh
	su -c "git clone https://github.com/robbyrussell/oh-my-zsh.git .oh-my-zsh" -m - $USERNAME
	chsh $USERNAME -s /bin/zsh

	# fetch dotfiles from repo
	su -c "git clone -b server https://github.com/jgiovaresco/dotfiles.git dotfiles" -m - $USERNAME

	# installs dotfiles
	su -c "HOME=/home/$USERNAME && cd ~/dotfiles && make" -m - $USERNAME

	# installs etc files
	cd "/home/$USERNAME/dotfiles" && make etc

	# install .vim files
	su -c "git clone https://github.com/jgiovaresco/.vim.git .vim" -m - $USERNAME
	su -c "git clone https://github.com/gmarik/vundle.git .vim/bundle/vundle" -m - $USERNAME
	su -c "ln -s /home/$USERNAME/.vim/.vimrc /home/$USERNAME/.vimrc" -m - $USERNAME
	ln -s "/home/$USERNAME/.vim" /root/.vim
	ln -s "/home/$USERNAME/.vimrc" /root/.vimrc
	)
}

configure_motd() {
	chmod +x /etc/update-motd.d/*
	rm /etc/motd
	ln -s /var/run/motd /etc/motd
}

print_manual_steps() {
	echo "To complete setup, run following commands :"
	echo " su -c "systemctl --user daemon-reload" - $USERNAME"
	echo " systemctl daemon-reload"
	echo " su -c "vim +BundleInstall +qall" - $USERNAME"
}

install_deluge() {
	# Deluge
	mkdir -p /var/downloads/deluge/deluged-config
	mkdir -p /var/downloads/deluge/deluge-web-config
	mkdir -p /var/downloads/deluge/downloads/complete
	mkdir -p /var/downloads/deluge/downloads/incoming
	mkdir -p /var/downloads/deluge/downloads/queue
	mkdir -p /var/downloads/deluge/downloads/torrents
	chown root.downloads -R /var/downloads/deluge
	chmod 775 -R /var/downloads/deluge
	# Enable service
	systemctl enable /etc/systemd/system/deluged.service
	systemctl enable /etc/systemd/system/deluge-web.service
	# Start service (control progression with 'journalctl -f')
	systemctl start deluged.service
	systemctl start deluge-web.service
}

install_sabnzbd() {
	# Directories
	mkdir -p /var/downloads/newsgrp/sabnzbd-config
	mkdir -p /var/downloads/newsgrp/downloads/cache
	mkdir -p /var/downloads/newsgrp/downloads/complete
	mkdir -p /var/downloads/newsgrp/downloads/incomplete
	mkdir -p /var/downloads/newsgrp/downloads/queue
	chown root.downloads -R /var/downloads/newsgrp
	chmod 775 -R /var/downloads/newsgrp
	# Enable service
	systemctl enable /etc/systemd/system/sabnzbd.service
	# Start service (control progression with 'journalctl -f')
	systemctl start sabnzbd.service
}

install_applications() {
	install_deluge
	install_sabnzbd
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
		echo "----> Install server packages"
		packages_server
		echo "----> Configure main user"
		configure_main_user
		echo "----> Configure motd"
		configure_motd
		echo "----> End of setup"
		print_manual_steps
		clean
	elif [[ $cmd == "install-packages" ]]; then
		check_is_sudo
		packages_server
		clean
	elif [[ $cmd == "main-user" ]]; then
		check_is_sudo
		configure_main_user
	elif [[ $cmd == "motd" ]]; then
		configure_motd
	elif [[ $cmd == "docker" ]]; then
		install_docker
	elif [[ $cmd == "appli" ]]; then
		install_applications
	else
		usage
	fi
}

main "$@"
