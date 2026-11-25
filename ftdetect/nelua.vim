" Nelua filetype detection for Vim. Neovim uses ftdetect/nelua.lua instead.
if has("nvim")
  finish
endif
au BufNewFile,BufRead *.nelua setf nelua
" Scripts without an extension: "#!/usr/bin/env nelua" or "#!/path/to/nelua"
au BufNewFile,BufRead * if getline(1) =~# '^#!.*[/ ]nelua\%(\s\|$\)' | set filetype=nelua | endif
