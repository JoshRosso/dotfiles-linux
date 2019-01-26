" -----------------------------------------------------------------------------
" plugins
" -----------------------------------------------------------------------------
call plug#begin('~/.vim/plugged')

Plug 'mileszs/ack.vim'
Plug 'kien/ctrlp.vim' "file fuzzy search
Plug 'scrooloose/nerdtree'
Plug 'NLKNguyen/papercolor-theme'
Plug 'majutsushi/tagbar'
Plug 'fatih/vim-go'

call plug#end()

" -----------------------------------------------------------------------------
" colors
" -----------------------------------------------------------------------------
set t_Co=256 "required for urxvt
set background=dark "dark or light
colorscheme PaperColor

" -----------------------------------------------------------------------------
" settings
" -----------------------------------------------------------------------------
filetype on "detect files based on type
filetype plugin on "when a file is edited its plugin file is loaded 
                   "(if there is one for the detected filetype) 
filetype indent on "maintain indentation

set incsearch "persist search highlight
set hlsearch "highlight as search matches
set mouse=a "use the mouse; you're a terrible person
set noswapfile "the world is a better place without swap
set nobackup "backups never helped anyone
set nu "enable line numbers
set splitbelow "default open splits below (e.g. :GoDoc)

let g:ackprg = 'ag --vimgrep' "use ag instead of ack

" -----------------------------------------------------------------------------
" mapping
" -----------------------------------------------------------------------------
let mapleader = "," "leader key is ','
" nerd tree
noremap <Leader>n :NERDTreeToggle<cr>
noremap <Leader>f :NERDTreeFind<cr>
"! ensures first result is not auto opened
nnoremap <Leader>a :Ack!<Space>
nnoremap <Leader>t :Tagbar<cr>
"ctl+space for assist
inoremap <C-@> <c-x><c-o>
nnoremap <Leader>m :set spell<cr>
