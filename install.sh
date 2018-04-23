pacman -Sy --needed \
	networkmanager \
	i3-wm \
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
	ttf-symbola \
	imagemagick \
	mutt \
	xf86-video-intel


# todo (install vim-plug)
# should not be root to do this
#if [-f ~/.vim/autoload/plug.vim does not exist ]; then
#  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
#      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
#fi

# TEMP_DIR=$(mktemp -d)

# cd $TEMP_DIR
#git clone https://aur.archlinux.org/spotify.git
#git clone https://aur.archlinux.org/slack-desktop.git
#git clone https://aur.archlinux.org/golang-dep.git
#git clone https://aur.archlinux.org/signal-desktop-bin.git
# git clone https://aur.archlinux.org/kubectl-bin.git
#cd spotify && makepkg -si && cd $TEMP_DIR
#cd slack-desktop && makepkg -si && cd $TEMP_DIR
#cd golang-dep && makepkg -si && cd $TEMP_DIR
#cd signal-desktop-bin && makepkg -si && cd $TEMP_DIR
# cd kubectl-bin && makepkg -si && cd $TEMP_DIR

# printf "[main]\ndhcp=dhclient" > /etc/NetworkManager/conf.d/dhcp-client.conf
