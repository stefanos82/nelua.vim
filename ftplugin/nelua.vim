" Vim filetype plugin file
" Language:     Nelua (https://nelua.io)
" Last Change:  2026-11-25
" Origin:       nelua.vim by Stefanos Sofroniou, itself derived from Vim's
"               ftplugin/lua.vim (Doug Kearns, Max Ischenko, Dorai Sitaram,
"               C.D. MacEachern, Tyler Miller). See README.md.
"
" Options:
"   g:nelua_recommended_style  0 = leave indentation options alone
"                              (default 1: 2-space indent, the style used by
"                              nelua-lang's own sources and documentation)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:---,:--
setlocal commentstring=--\ %s
setlocal formatoptions-=t formatoptions+=croql

" [[ and ]] style jumps / :ilist: definitions
let &l:define = '\<function\|\<\%(local\|global\)\%(\s\+function\)\='

" gf on  require 'foo.bar'  opens foo/bar.nelua
setlocal includeexpr=tr(v:fname,'.','/')
setlocal suffixesadd=.nelua

let b:undo_ftplugin = "setlocal com< cms< fo< def< inex< sua<"

if get(g:, "nelua_recommended_style", 1)
  setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=8
  let b:undo_ftplugin ..= " | setlocal et< sw< sts< ts<"
endif

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0
  let b:match_words =
        \ '\<\%(do\|function\|if\|switch\)\>:' ..
        \ '\<\%(return\|else\|elseif\|case\)\>:' ..
        \ '\<end\>,' ..
        \ '\<repeat\>:\<until\>,' ..
        \ '\%(--\|##\)\=\[\(=*\)\[:]\1]'
  let b:undo_ftplugin ..= " | unlet! b:match_words b:match_ignorecase"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Nelua Source Files (*.nelua)\t*.nelua\n" ..
        \ "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: et ts=8 sw=2
