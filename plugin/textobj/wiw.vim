"=============================================================================
" textobj-wiw - Text objects to select a range of words for humans.
"
" File    : plugin/textobj/wiw.vim
" Author  : h1mesuke <himesuke@gmail.com>
" Updated : 2012-01-09
" Version : 0.0.1
" License : MIT license {{{
"
"   Permission is hereby granted, free of charge, to any person obtaining
"   a copy of this software and associated documentation files (the
"   "Software"), to deal in the Software without restriction, including
"   without limitation the rights to use, copy, modify, merge, publish,
"   distribute, sublicense, and/or sell copies of the Software, and to
"   permit persons to whom the Software is furnished to do so, subject to
"   the following conditions:
"
"   The above copyright notice and this permission notice shall be included
"   in all copies or substantial portions of the Software.
"
"   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"   CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

if exists('g:loaded_textobj_wiw') && g:loaded_textobj_wiw
  finish
endif
let g:loaded_textobj_wiw = 1

let s:save_cpo = &cpo
let s:save_ic  = &ignorecase
set cpo&vim
set noignorecase
" NOTE: Disable 'ignorecase' to avoid textobj-user's bug that defines key
" mappings incorrectly when 'ignorecase' is enabled.

let s:prefix = get(g:, 'textobj_wiw_default_key_mappings_prefix', ',')

" Key-mappings
call textobj#user#plugin('wiw', {
      \ '-': {
      \   '*pattern*': 'DUMMY',
      \   'move-n'   : s:prefix . 'w',
      \   'move-p'   : s:prefix . 'b',
      \   'move-N'   : s:prefix . 'e',
      \   'move-P'   : s:prefix . 'ge',
      \
      \   '*sfile*'  : expand('<sfile>:p'),
      \   'select-a' : 'a' . s:prefix . 'w', '*select-a-function*': 's:select_a',
      \   'select-i' : 'i' . s:prefix . 'w', '*select-i-function*': 's:select_i',
      \ }
      \})
unlet s:prefix

let s:WIW_HEAD = '\%(\(\<.\)\|\(\u\l\|\l\@<=\u\)\|\(\A\@<=\a\)\)'
let s:WIW_TAIL = '\%(\(.\>\)\|\(\l\u\@=\|\u\%(\u\l\)\@=\)\|\(\a\A\@=\)\)'

" Sub-match types
let s:NOT_FOUND  = 0

let s:WORD_BOUND = 2
" Example: <this> <is> <a> <wiw>

let s:CASE_BOUND = 3
" Example: <This><Is><A><Wiw>

let s:CTYPE_BOUND = 4
" Example: <this>_<is>_<a>_<wiw>
" Example: <this>#<is>#<a>#<wiw>

" NOTE: Sub-match number starts from 2 because 1 means that none of the
" sub-matches matched but the whole pattern did match. See :help
" search()-sub-match.


" Override move function to share s:move() with s:select().
function! g:__textobj_wiw.move(obj_name, flags, previous_mode)
  if a:previous_mode ==# 'v'
    normal! gv
  endif
  let pattern = (a:flags =~# 'e' ? s:WIW_TAIL : s:WIW_HEAD)
  let flags   = (a:flags =~# 'b' ? 'b' : '')
  call s:move(pattern, flags, v:count1, 0)
endfunction

function! s:move(pattern, flags, count, within_word)
  let flags = a:flags
  let submatch = s:NOT_FOUND
  for i in range(a:count)
    let result = search(a:pattern, 'p' . flags)
    if result == s:NOT_FOUND
      if i == 0
        return result
      else
        break
      endif
    elseif result == s:WORD_BOUND && a:within_word
      let submatch = result
      break
    endif
    if i == 0
      let flags = substitute(flags, 'c', '', 'g')
    endif
    let submatch = result
  endfor
  return submatch
endfunction

function! s:select_a()
  return s:select(0)
endfunction

function! s:select_i()
  return s:select(1)
endfunction

function! s:select(inner)
  let save_ww = &whichwrap
  set whichwrap-=h,l

  try
    if !s:cursor_is_in_word()
      call s:move(s:WIW_HEAD, '', 1, 0)
    endif

    let delim_included = 0
    let pos = getpos('.')

    " Get the column position where the selection ends.
    let submatch = s:move(s:WIW_TAIL, 'cW', v:count1, 1)
    if submatch == s:NOT_FOUND
      return 0
    endif
    if !a:inner
      if submatch == s:CTYPE_BOUND
        " Include a trailing delimiter.
        " NOTE: Only ctype bounds have delimiters.
        normal! l
        let delim_included = 1
      endif
    endif
    let end = getpos('.')

    call setpos('.', pos)

    " Get the column position where the selection starts.
    let submatch = s:move(s:WIW_HEAD, 'cbW', 1, 1)
    if submatch == s:NOT_FOUND
      return 0
    endif
    if !a:inner && !delim_included
      if submatch == s:CTYPE_BOUND
        " Include a leading delimiter.
        normal! h
      endif
    endif
    let start = getpos('.')

    return ['v', start, end]

  finally
    let &whichwrap = save_ww
  endtry
endfunction

function! s:cursor_is_in_word()
  " The cursor is in a word when:
  "   cursor < tail < head or EOF
  let tail_pos = searchpos('.\>', 'cnW')
  if tail_pos[0] > 0
    let head_pos = searchpos('\<.', 'nW')
    if head_pos[0] > 0
      " return (tail_pos < head_pos)
      return (s:compare_pos(tail_pos, head_pos) <= 0)
    else
      " The cursor is in the last word.
      return 1
    endif
  endif
  return 0
endfunction

" NOTE: This function is compatible with sort().
function! s:compare_pos(pos1, pos2)
  if a:pos1[0] == a:pos2[0]
    return (a:pos1[1] == a:pos2[1] ? 0 : (a:pos1[1] > a:pos2[1] ? 1 : -1))
  else
    return (a:pos1[0] > a:pos2[0] ? 1 : -1)
  endif
endfunction

let &cpo = s:save_cpo
let &ignorecase = s:save_ic
unlet s:save_cpo
unlet s:save_ic
