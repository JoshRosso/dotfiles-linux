set t_Co=256
set nocompatible              " be iMproved, required
filetype off                  " required
syntax on

set background=dark
colorscheme PaperColor

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'
Plugin 'fatih/vim-go'
Plugin 'Valloric/YouCompleteMe'
Plugin 'tpope/vim-surround'
Plugin 'scrooloose/nerdtree'
Plugin 'majutsushi/tagbar'
Plugin 'NLKNguyen/papercolor-theme'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
set nu
set tabstop=2 softtabstop=0 expandtab shiftwidth=2

" Move between tabs with ctrl+h / ctrl+l
map  <C-l> :tabn<CR>
map  <C-h> :tabp<CR>

" Launch NERDTree with ctrl+n
map  <C-n> :NERDTree<CR>

" Toggle tagbar
map  <C-d> :TagbarToggle<CR>
