" Ensure VIM uses syntax highlighting
syntax enable

" Color Scheme from https://github.com/lsdr/monokai
colorscheme monokai 

" Indentation with spacing at 2 and tabs turned to spaces
" http://vim.wikia.com/wiki/Indenting_source_code
set expandtab
set shiftwidth=2
set softtabstop=2

" Display line numbers
:set number

" Enable filetype plugin
filetype plugin indent on

" Autoindent by default
set autoindent

" Load up Pathogen
execute pathogen#infect()

" Quickly show invisibles with: \l 
nmap <leader>l :set list!<CR>

" Tabs - Switch between tabs with ctrl+h / ctrl+l
map  <C-l> :tabn<CR>
map  <C-h> :tabp<CR>

map <C-n> :NERDTree<CR>

" Use textmate's invisible symbols
set listchars=tab:▸\ ,eol:¬

" Vundle - https://github.com/gmarik/Vundle.vim
" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
" call vundle#begin('~/some/path/here')
" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'
Plugin 'xolox/vim-misc'
Plugin 'xolox/vim-notes'
Plugin 'scrooloose/nerdtree'

" -- BEGIN SCRIPTS --

" Set tabstop, softtabstop and shiftwidth to the same value
command! -nargs=* Stab call Stab()
function! Stab()
  let l:tabstop = 1 * input('set tabstop = softtabstop = shiftwidth = ')
  if l:tabstop > 0
    let &l:sts = l:tabstop
    let &l:ts = l:tabstop
    let &l:sw = l:tabstop
  endif
  call SummarizeTabs()
endfunction

function! SummarizeTabs()
  try
    echohl ModeMsg
    echon 'tabstop='.&l:ts
    echon ' shiftwidth='.&l:sw
    echon ' softtabstop='.&l:sts
    if &l:et
      echon ' expandtab'
    else
      echon ' noexpandtab'
    endif
  finally
    echohl None
  endtry
endfunction
