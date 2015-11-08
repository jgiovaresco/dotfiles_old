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

	# install oh-my-zsh
	su -c "git clone https://github.com/robbyrussell/oh-my-zsh.git .oh-my-zsh" -m $USERNAME
	chsh $USERNAME -s /bin/zsh

	# install dotfiles from repo
	su -c "git clone https://github.com/jgiovaresco/dotfiles.git dotfiles" -m $USERNAME
	cd "/home/$USERNAME/dotfiles"

	# installs all the things
	su -c "make"

	cd "/home/$USERNAME"

	# install .vim files
	su -c "git clone https://github.com/jgiovaresco/.vim.git .vim" -m $USERNAME
	su -c "git clone https://github.com/gmarik/vundle.git .vim/bundle/vundle" -m $USERNAME
	su -c "ln -s /home/$USERNAME/.vim/.vimrc /home/$USERNAME/.vimrc" -m $USERNAME
	ln -s "/home/$USERNAME/.vim" /root/.vim
	ln -s "/home/$USERNAME/.vimrc" /root/.vimrc
	
	echo "To install VIM plugins (ignore potential error messages at the first start)"
	echo "run vim +BundleInstall +qall"
	)
}

configure_motd() {
	chmod +x /etc/update-motd.d/*
	rm /etc/motd
	ln -s /var/run/motd /etc/motd
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
	else
		usage
	fi
}

main "$@"