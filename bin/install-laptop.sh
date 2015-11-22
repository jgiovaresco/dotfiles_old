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

	/bin/bash -c "$(wget https://raw.githubusercontent.com/jgiovaresco/dotfiles/laptop/bin/install-base.sh --no-cache -O -) base"
	create_fstab
	update_rights_on_dir
}

create_fstab() {
	cat <<-EOF > /etc/fstab
	/dev/sb1					/boot           ext4    defaults        0       2

	/dev/mapper/HDD-swap		none            swap    sw              0       0

	/dev/mapper/SSD-root		/				ext4    noatime,errors=remount-ro	0       1
	/dev/mapper/SSD-home		/home			ext4    noatime,defaults			0       2
	/dev/mapper/HDD-cache		/var/cache		ext4    defaults					0       2	/dev/mapper/HDD-documents 	/var/documents  ext4    defaults					0       2
	/dev/mapper/HDD-documents	/var/documentsi	ext4    defaults					0       2
	/dev/mapper/HDD-downloads	/var/downloads	ext4    defaults					0       2
	/dev/mapper/HDD-docker		/var/lib/docker	ext4    defaults					0       2
	/dev/mapper/HDD-log 		/var/log		ext4    defaults					0       2

	none	/tmp		tmpfs	defaults	0	0
	none	/var/spool	tmpfs	defaults	0	0
	none	/var/.cache	tmpfs	defaults	0	0
	EOF
}

update_rights_on_dir() {
	chown root.users -R /var/downloads
	chown root.users -R /var/documents
	
	chmod g+w -R /var/downloads
	chmod g+w -R /var/documents
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
		feh \
		fonts-croscore\
		fonts-font-awesome \
		libnotify-bin \
		rxvt-unicode-256color \
		scdaemon \
		sudo \
		xclip \
		xcompmgr \
		xz-utils \
		wicd-cli \
		wicd-ncurses \
		--no-install-recommends

	# install tlp with recommends
	apt-get install -y tlp
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
	sudo gpasswd -a $USERNAME downloads
	sudo gpasswd -a $USERNAME multimedia
	sudo gpasswd -a $USERNAME ebooks
	sudo gpasswd -a $USERNAME photos
	sudo gpasswd -a $USERNAME docker

	# fetch oh-my-zsh
	su -c "git clone https://github.com/robbyrussell/oh-my-zsh.git .oh-my-zsh" -m - $USERNAME
	chsh $USERNAME -s /bin/zsh

	# fetch dotfiles from repo
	su -c "git clone -b laptop https://github.com/jgiovaresco/dotfiles.git dotfiles" -m - $USERNAME
	
	# installs dotfiles
	su -c "HOME=/home/$USERNAME && cd ~/dotfiles && make" -m - $USERNAME

	# installs etc files
	cd "/home/$USERNAME/dotfiles" && make etc
	
	cd "/home/$USERNAME"

	# install .vim files
	su -c "git clone https://github.com/jgiovaresco/.vim.git .vim" -m - $USERNAME
	su -c "git clone https://github.com/gmarik/vundle.git .vim/bundle/vundle" -m - $USERNAME
	su -c "ln -s /home/$USERNAME/.vim/.vimrc /home/$USERNAME/.vimrc" -m - $USERNAME
	ln -s "/home/$USERNAME/.vim" /root/.vim
	ln -s "/home/$USERNAME/.vimrc" /root/.vimrc

	# Bind directories
	mkdir -p /var/documents/Documents
	mkdir -p /var/documents/Ebooks
	mkdir -p /var/documents/Music
	mkdir -p /var/documents/Pictures
	mkdir -p /var/documents/Videos

	ln -s /var/documents/Documents /home/$USERNAME/Documents
	ln -s /var/documents/Ebooks /home/$USERNAME/Ebooks
	ln -s /var/documents/Music /home/$USERNAME/Music
	ln -s /var/documents/Pictures /home/$USERNAME/Pictures
	ln -s /var/documents/Videos /home/$USERNAME/Videos
	ln -s /var/downloads /home/$USERNAME/Downloads
	)
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
}

install_wm() {

	local pkgs_stable="slim scrot imagemagick"
	local pkgs_testing="i3 i3lock i3status"

	apt-get install -y $pkgs_stable --no-install-recommends
	apt-get install -y -t testing $pkgs_testing --no-install-recommends

	# add xorg conf
	curl -sSL https://raw.githubusercontent.com/jgiovaresco/dotfiles/laptop/etc/X11/xorg.conf > /etc/X11/xorg.conf

	# pretty fonts
	curl -sSL https://raw.githubusercontent.com/jgiovaresco/dotfiles/laptop/etc/fonts/local.conf > /etc/fonts/local.conf
}

clean() {

	sudo apt-get autoremove
	sudo apt-get autoclean

}

print_manual_steps() {
	echo "To complete setup, run following commands as $USERNAME :"
	echo "1. sudo dpkg-reconfigure fontconfig-config with settings: "
	echo "	Autohinter, Automatic, No."
	echo "2. sudo update-grub && sudo reboot"
	echo "3. ./install-laptop.sh end"
}

end_installation() {

	# enable dbus for the user session
	systemctl --user enable dbus.socket
	systemctl --user enable dbus.service
	systemctl --user start dbus
	
	sudo systemctl enable i3lock
	sudo systemctl enable suspend-sedation.service

	sudo systemctl daemon-reload
	systemctl --user daemon-reload

	vim +BundleInstall +qall

	sudo update-grub
}

usage() {
	echo -e "install.sh\n\tThis script installs my basic setup for a debian laptop\n"
	echo "Usage:"
	echo "  all 						- complete setup"
	echo "  install-packages            - install laptop base pkgs"
	echo "  network                     - install network drivers"
	echo "  graphics                    - install graphics drivers"
	echo "  wm                    		- install window manager / configure desktop"
	echo "  audio                  		- install / configure sound"
	echo "  main-user              		- configure main user"
	echo "  end                			- Finish setup"
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
		check_is_sudo
		configure_main_user
		clean
	elif [[ $cmd == "end" ]]; then
		end_installation
		clean
	else
		usage
	fi
}

main "$@"
