# requires sudo
pacman -Sy --needed \
	networkmanager \
	i3-wm \
	i3status \
	i3blocks \
	i3lock \
	rxvt-unicode \
	dhclient \
	network-manager-applet \
	openconnect \
	go \
	bash-completion \
	pass \
	xorg \
	xorg-xinit \
	openssh \
	ttf-inconsolata \
	chromium \
	firefox \
	dmenu \
	vim --asdeps lua \
	alsa-utils \
	volumeicon \
	bluez \
	bluez-utils \
	arandr \
	ctags \
	imagemagick \
	mutt \
	jdk10-openjdk \
	docker \
	terraform \
	the_silver_searcher \
	ttf-hack \
	xf86-video-intel

printf "[main]\ndhcp=dhclient" > /etc/NetworkManager/conf.d/dhcp-client.conf
printf "[Policy]\nAutoEnable=true" > /etc/bluetooth/main.conf
systemctl enable NetworkManager
systemctl enable bluetooth
