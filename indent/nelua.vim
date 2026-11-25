" Vim indent file
" Language:     Nelua (https://nelua.io)
" Last Change:  2026-11-25
"
" Counts block openers/closers on the previous line, like Vim's Lua indent.
" Nelua specifics, following the style of nelua-lang's own lib/*.nelua:
"   * "switch x do" does not indent; "case ... then" indents its body
"     (cases sit at the switch's level, as in the official docs).
"   * Preprocessor lines ("## for ... do", "## else", "## end") take part in
"     indentation like normal code, which is what lib/*.nelua mostly does.
"   * The "]]" closing a "##[[" block lines up with the line that opened it.
"   * At most one indent level per line:  foo({  indents once.
" Lines inside long comments/strings keep their indentation.

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetNeluaIndent()
setlocal indentkeys+=0=end,0=until,0=elseif,0=else,0=case,0=},0=),0=]
setlocal autoindent nolisp nosmartindent
let b:undo_indent = "setlocal indentexpr< indentkeys< autoindent< lisp< smartindent<"

if exists("*GetNeluaIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Blank out strings and comments so their contents are not counted.
function! s:Code(lnum) abort
  let l = getline(a:lnum)
  let l = substitute(l, '^\s*##\%(\[=*\[\)\@!', '', '')
  let l = substitute(l, '\\.', '', 'g')
  let l = substitute(l, '"[^"]*"', '""', 'g')
  let l = substitute(l, "'[^']*'", "''", 'g')
  let l = substitute(l, '\[\(=*\)\[.\{-}\]\1\]', '""', 'g')
  let l = substitute(l, '--.*$', '', '')
  " long brackets that open or close on another line do not indent
  let l = substitute(l, '\[=*\[\|\]=*\]', '', 'g')
  return l
endfunction

function! s:Count(str, pat) abort
  let n = 0
  let start = 0
  while 1
    let start = matchend(a:str, a:pat, start)
    if start < 0
      return n
    endif
    let n += 1
  endwhile
endfunction

function! s:InCommentOrString(lnum) abort
  let name = synIDattr(synID(a:lnum, 1, 1), "name")
  return name =~# '^nelua\%(Comment\|LongString\|String\|StringDelim\)$'
endfunction

function! GetNeluaIndent() abort
  if s:InCommentOrString(v:lnum)
    return -1
  endif
  let plnum = prevnonblank(v:lnum - 1)
  if plnum == 0
    return 0
  endif
  let sw = shiftwidth()
  let curline = getline(v:lnum)

  " "]]" closing a long bracket opened on an earlier line ("##[[ ... ]]")
  if curline =~# '^\s*\]=*\]'
    let close = matchstr(curline, '^\s*\zs\]=*\]')
    let open = '[' . repeat('=', strlen(close) - 2) . '['
    for l in range(v:lnum - 1, max([1, v:lnum - 1000]), -1)
      if stridx(getline(l), open) >= 0
        " align only with a block that starts its line ("##[[" / "[["); an
        " opener in the middle of a line falls through to normal counting
        if getline(l) =~# '^\s*\%(##\)\=\['
          return indent(l)
        endif
        break
      endif
    endfor
  endif

  let ind = indent(plnum)
  let prev = s:Code(plnum)
  let cur = s:Code(v:lnum)

  " Net openers on the previous line. Leading closers ("end", "})", "end)")
  " were already dedented when that line was indented: not counted again.
  let body = substitute(prev, '^\s*\%(\%(end\>\|until\>\|[})\]]\)\s*\)\+', '', '')
  let opens = s:Count(body, '\<\%(then\|repeat\|defer\)\>\|[({[]')
  let opens += s:Count(body, '^\s*else\>')
  " function bodies, but not function types  (x: function(...), @function(...))
  let opens += s:Count(body, '\%([:@]\s*\)\@<!\<function\>')
  " "do" opens a block, except in "switch x do"
  if body !~# '\<switch\>'
    let opens += s:Count(body, '\<do\>')
  endif
  let closes = s:Count(body, '\<\%(end\|until\)\>\|[)}\]]')
  " At most one level per line, as in Lua/Nelua style:  foo({  indents once.
  let net = opens - closes
  let ind += sw * (net > 0 ? 1 : net < 0 ? -1 : 0)

  " The current line closes a block.
  if cur =~# '^\s*\%(end\>\|until\>\|else\>\|elseif\>\|[})\]]\)'
    let ind -= sw
  elseif cur =~# '^\s*case\>' && prev !~# '^\s*switch\>'
    let ind -= sw
  endif
  return ind < 0 ? 0 : ind
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: et ts=8 sw=2
