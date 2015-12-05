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

clean() {

	sudo apt-get autoremove
	sudo apt-get autoclean

}

install_java(){
	JAVA_MAJOR=8
	JAVA_UPDATE=65
	JAVA_BUILD=17
	wget -O /tmp/jdk.tar.gz --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/${JAVA_MAJOR}u${JAVA_UPDATE}-b${JAVA_BUILD}/jdk-${JAVA_MAJOR}u${JAVA_UPDATE}-linux-x64.tar.gz

	mkdir -p /home/$USERNAME/DEV/tools/jdk
	tar xzf /tmp/jdk.tar.gz -C /home/$USERNAME/DEV/tools/jdk
	
	install_jenv
}
install_jenv(){
	git clone git@github.com:jgiovaresco/jenv.git /home/$USERNAME/.jenv

	mkdir /home/$USERNAME/.jenv/versions
}

install_nvm(){
	curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.29.0/install.sh | bash

	mkdir /var/cache/npm
	chown root.users /var/cache/npm
	chmod g+w /var/cache/npm
	ln -s /var/cache/npm /home/$USERNAME/.npm
}

usage() {
	echo -e "install.sh\n\tThis script installs my basic setup for a debian laptop\n"
	echo "Usage:"
	echo "  java               			- install Java"
	echo "  nvm                			- install NVM"
}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi
	
	if [[ $cmd == "nvm" ]]; then
		install_nvm
	elif [[ $cmd == "java" ]]; then
		install_java
	else
		usage
	fi
}

main "$@"
