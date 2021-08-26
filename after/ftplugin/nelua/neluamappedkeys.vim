setlocal shiftwidth=2
setlocal tabstop=2

nmap <F5> :up <bar> !clear; /usr/bin/env nelua %<CR>
nmap <S-F5> :up <bar> !clear; /usr/bin/env nelua -TV %<CR>
