""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" OriginalAuthor: Samuel Roeca
" Maintainer:     Samuel Roeca samuel.roeca@gmail.com
" Description:    nvim-repl: configure and work with a repl
" License:        MIT License
" Website:        https://github.com/pappasam/nvim-repl
" License:        MIT
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:id_window = v:false
let s:id_job = v:false

function! repl#warning(msg)
  echohl WarningMsg
  echom 'repl: ' . a:msg
  echohl None
endfunction

function! s:cleanup()
  call jobstop(s:id_job)
  let s:id_window = v:false
  let s:id_job = v:false
  let s:repl_description = v:false
endfunction

function! s:setup()
  setlocal nonumber nornu nobuflisted
  autocmd WinClosed <buffer> call s:cleanup()
endfunction

function! s:repl_reset_visual_position()
  set lazyredraw
  let current_window_id = win_getid()
  call win_gotoid(s:id_window)
  normal! G
  call win_gotoid(current_window_id)
  set nolazyredraw
  redraw
endfunction

function! repl#open(...)
  if s:id_window != v:false
    call repl#warning('already open. To close existing repl, run ":ReplClose"')
    return
  endif
  let current_window_id = win_getid()
  let func_args = a:000
  let s:repl_description = len(func_args) == 0 ?
        \ get(g:repl_filetype_commands, &filetype, g:repl_default) :
        \ func_args[0]
  let command = type(s:repl_description) == v:t_dict ? get(s:repl_description, 'cmd') : s:repl_description
  if g:repl_split == 'vertical'
    execute 'vertical ' . g:repl_width . 'split new'
  elseif g:repl_split == 'left'
    execute 'leftabove vertical ' . g:repl_width . 'split new'
  elseif g:repl_split == 'right'
    execute 'rightbelow vertical ' . g:repl_width . 'split new'
  elseif g:repl_split == 'horizontal'
    execute g:repl_height . 'split new'
  elseif g:repl_split == 'bottom'
    execute 'rightbelow ' . g:repl_height . 'split new'
  elseif g:repl_split == 'top'
    execute 'leftabove ' . g:repl_height . 'split new'
  else
    throw 'Something went wrong, file issue with https://github.com/pappasam/nvim-repl...'
  endif
  let s:id_job = termopen(command)
  let s:id_window = win_getid()
  call s:setup()
  call win_gotoid(current_window_id)
endfunction

function! repl#close()
  let current_window_id = win_getid()
  call win_gotoid(s:id_window)
  quit
  call win_gotoid(current_window_id)
endfunction

function! repl#toggle()
  if s:id_window == v:false
    call repl#open()
  else
    call repl#close()
  endif
endfunction

function! repl#send() range
  if s:id_window == v:false
    call repl#warning('no repl currently open. Run ":ReplOpen" first')
    return
  endif
  let buflines_raw = getbufline(bufnr('%'), a:firstline, a:lastline)
  let buflines_header = a:firstline == 1 ?
        \ [''] :
        \ getbufline(bufnr('%'), a:firstline - 1)
  let buflines_footer = a:lastline == line('$') ?
        \ [''] :
        \ getbufline(bufnr('%'), a:lastline + 1)
  let buflines = buflines_header + buflines_raw + buflines_footer
  let buflines_clean = []
  " [0, 1, 2, 3, 4, 5]: starts at '1', ends at '4'
  let count = 1
  while count <= len(buflines_raw)
    let bl_prev = buflines[count - 1]
    let bl_curr = buflines[count]
    let bl_next = buflines[count + 1]
    let ws_prev = matchstr(bl_prev, '^\s\+')
    let ws_curr = matchstr(bl_curr, '^\s\+')
    let ws_next = matchstr(bl_next, '^\s\+')
    if bl_curr == ''
      let ws_add = bl_next == '' ? ws_prev : ws_next
      let bl_clean = ws_add . bl_curr
    else
      let bl_clean = bl_curr
    endif
    " If the previous line is more indented, add extra indent before. Will
    " change value of some multi-line strings but will generally offer
    " better-support for Python / indented languages without introducing
    " code-based bugs to non-indentation-based languages
    let buflines_clean = len(ws_curr) < len(ws_prev) ?
          \ buflines_clean + ['', bl_clean] :
          \ buflines_clean + [bl_clean]
    let count = count + 1
  endwhile
  if count > 2
    let before_multiline = get(s:repl_description, 'before_multiline', '')
    if before_multiline != ''
      call insert(buflines_clean, before_multiline) " prepend
    endif
    let after_multiline = get(s:repl_description, 'after_multiline', '')
    if after_multiline != ''
      call add(buflines_clean, after_multiline) " append
    endif
  endif
  let buflines_chansend =
        \ a:lastline == line('$') && match(buflines_clean[-1], '^\s\+') == 0 ?
        \ buflines_clean + ['', ''] :
        \ buflines_clean + ['']
  call chansend(s:id_job, buflines_chansend)
  call s:repl_reset_visual_position()
endfunction

function! repl#clear()
  if s:id_window == v:false
    call repl#warning('no repl currently open. Run ":ReplOpen" first')
    return
  endif
  call chansend(s:id_job, "\<c-l>")
endfunction
