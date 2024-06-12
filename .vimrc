set number
set relativenumber
syntax on
set tabstop=2
set shiftwidth=4
set expandtab
set smartindent
set softtabstop=4
set backspace=indent,eol,start
set updatetime=100

call plug#begin('~/.vim/plugged')

Plug 'arcticicestudio/nord-vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

call plug#end()

colorscheme nord
