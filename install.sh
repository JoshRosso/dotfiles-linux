# must be non-root
if [ ! -e ~/.vim/autoload/plug.vim ]; then
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

if ! pacman -Qs spotify > /dev/null; then 
	git clone https://aur.archlinux.org/spotify.git
	cd spotify && makepkg -si && cd $TEMP_DIR
fi

if ! pacman -Qs slack > /dev/null; then 
	git clone https://aur.archlinux.org/slack-desktop.git
	cd slack-desktop && makepkg -si && cd $TEMP_DIR
fi

if ! pacman -Qs golang-dep > /dev/null; then 
	git clone https://aur.archlinux.org/golang-dep.git
	cd golang-dep && makepkg -si && cd $TEMP_DIR
fi

if ! pacman -Qs signal-desktop > /dev/null; then 
	git clone https://aur.archlinux.org/signal-desktop-bin.git
	cd signal-desktop-bin && makepkg -si && cd $TEMP_DIR
fi

if ! pacman -Qs kubectl > /dev/null; then 
	git clone https://aur.archlinux.org/kubectl-bin.git
	cd kubectl-bin && makepkg -si && cd $TEMP_DIR
fi


if ! pacman -Qs ttf-symbola > /dev/null; then 
	git clone https://aur.archlinux.org/ttf-symbola.git
	cd ttf-symbola && makepkg -si && cd $TEMP_DIR
fi
