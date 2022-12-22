" bullets/plugin/init.vim
" Author: Keith Miyake
" Author: Dorian Karter
" Forked from bullets.nvim
" License: GPLv3, MIT

" Preserve Vim compatibility settings -------------------  {{{
let s:save_cpo = &cpoptions
set cpoptions&vim
" -------------------------------------------------------  }}}

" Prevent execution if already loaded ------------------   {{{
if exists('g:loaded_bullets_vim')
  finish
endif
let g:loaded_bullets_vim = 1
" Prevent execution if already loaded ------------------   }}}

" Read user configurable options -----------------------   {{{
if !exists('g:bullets_enabled_file_types')
  let g:bullets_enabled_file_types = ['markdown', 'text', 'gitcommit']
endif

if !exists('g:bullets_enable_in_empty_buffers')
  let g:bullets_enable_in_empty_buffers = 1
end

if !exists('g:bullets_set_mappings')
  let g:bullets_set_mappings = 1
end

if !exists('g:bullets_mapping_leader')
  let g:bullets_mapping_leader = ''
end

" Extra key mappings in addition to default ones.
" If you don’t need default mappings set 'g:bullets_set_mappings' to '0'.
" N.B. 'g:bullets_mapping_leader' has no effect on these mappings.
"
" Example:
"   let g:bullets_custom_mappings = [
"     \ ['imap', '<cr>', '<Plug>(bullets-newline)'],
"     \ ]
if !exists('g:bullets_custom_mappings')
  let g:bullets_custom_mappings = []
endif

if !exists('g:bullets_delete_last_bullet_if_empty')
  let g:bullets_delete_last_bullet_if_empty = 1
end

if !exists('g:bullets_line_spacing')
  let g:bullets_line_spacing = 1
end

if !exists('g:bullets_pad_right')
  let g:bullets_pad_right = 1
end

if !exists('g:bullets_max_alpha_characters')
  let g:bullets_max_alpha_characters = 2
end
" calculate the decimal equivalent to the last alphabetical list item
let s:power = g:bullets_max_alpha_characters
let s:abc_max = -1
while s:power >= 0
  let s:abc_max += pow(26,s:power)
  let s:power -= 1
endwhile

if !exists('g:bullets_outline_levels')
  " Capitalization matters: all caps will make the symbol caps, lower = lower
  " Standard bullets should include the marker symbol after 'std'
  let g:bullets_outline_levels = ['ROM', 'ABC', 'num', 'abc', 'rom', 'std-', 'std*', 'std+']
endif

if !exists('g:bullets_renumber_on_change')
  let g:bullets_renumber_on_change = 1
endif

if !exists('g:bullets_nested_checkboxes')
  " Enable nested checkboxes that toggle parents and children when the current
  " checkbox status changes
  let g:bullets_nested_checkboxes = 1
endif

if !exists('g:bullets_checkbox_markers')
  " The ordered series of markers to use in checkboxes
  " If only two markers are listed, they represent 'off' and 'on'
  " When more than two markers are included, the (n) intermediate markers
  " represent partial completion where each marker is 1/n of the total number
  " of markers.
  " E.g. the default ' .oOX': ' ' = 0 < '.' <= 1/3 < 'o' < 2/3 < 'O' < 1 = X
  " This scheme is borrowed from https://github.com/vimwiki/vimwiki
  let g:bullets_checkbox_markers = ' .oOX'

  " You can use fancy symbols like this:
  " let g:bullets_checkbox_markers = '✗○◐●✓'

  " You can disable partial completion markers like this:
  " let g:bullets_checkbox_markers = ' X'
endif

if !exists('g:bullets_checkbox_partials_toggle')
  " Should toggling on a partially completed checkbox set it to on (1), off
  " (0), or disable toggling partially completed checkboxes (-1)
  let g:bullets_checkbox_partials_toggle = 1
endif

if !exists('g:bullets_auto_indent_after_colon')
  " Should a line ending in a colon result in the next line being indented (1)?
  let g:bullets_auto_indent_after_colon = 1
endif
" ------------------------------------------------------   }}}

lua bullets = require('bullets')

" Commands ------------------------------------------------ {{{
command! InsertNewBullet lua bullets.insert_new_bullet()
command! SelectCheckboxInside lua bullets.select_checkbox(1)
command! SelectCheckbox lua bullets.select_checkbox(0)
command! ToggleCheckbox lua bullets.toggle_checkboxes_nested()
command! -range=% RenumberSelection lua bullets.renumber_selection()
command! RenumberList lua bullets.renumber_whole_list()
command! BulletDemote lua bullets.change_bullet_level_and_renumber(-1)
command! BulletPromote lua bullets.change_bullet_level_and_renumber(1)
command! -range=% BulletDemoteVisual lua bullets.visual_change_bullet_level(-1)
command! -range=% BulletPromoteVisual lua bullets.visual_change_bullet_level(1)
command! SelectBullet lua bullets.select_bullet_item(line('.'))
command! SelectBulletText lua bullets.select_bullet_text(line('.'))
" ------------------------------------------------------   }}}
" Keyboard mappings --------------------------------------- {{{

" Automatic bullets
" inoremap <silent> <Plug>(bullets-newline) <C-]><C-R>=luaeval("bullets.insert_new_bullet()","")<cr>
inoremap <silent> <Plug>(bullets-newline) <C-O>:lua bullets.insert_new_bullet()<cr>
nnoremap <silent> <Plug>(bullets-newline) :lua bullets.insert_new_bullet()<cr>

" Renumber bullet list
vnoremap <silent> <Plug>(bullets-renumber) :RenumberSelection<cr>
nnoremap <silent> <Plug>(bullets-renumber) :RenumberList<cr>

" Toggle checkbox
nnoremap <silent> <Plug>(bullets-toggle-checkbox) :ToggleCheckbox<cr>

" Promote and Demote outline level
inoremap <silent> <Plug>(bullets-demote) <C-o>:BulletDemote<cr>
nnoremap <silent> <Plug>(bullets-demote) :BulletDemote<cr>
vnoremap <silent> <Plug>(bullets-demote) :BulletDemoteVisual<cr>
inoremap <silent> <Plug>(bullets-promote) <C-o>:BulletPromote<cr>
nnoremap <silent> <Plug>(bullets-promote) :BulletPromote<cr>
vnoremap <silent> <Plug>(bullets-promote) :BulletPromoteVisual<cr>
fun! s:add_local_mapping(with_leader, mapping_type, mapping, action)
  let l:file_types = join(g:bullets_enabled_file_types, ',')
  execute 'autocmd FileType ' .
        \ l:file_types .
        \ ' ' .
        \ a:mapping_type .
        \ ' <silent> <buffer> ' .
        \ (a:with_leader ? g:bullets_mapping_leader : '') .
        \ a:mapping .
        \ ' ' .
        \ a:action

  if g:bullets_enable_in_empty_buffers
    execute 'autocmd BufEnter * if bufname("") == "" | ' .
          \ a:mapping_type .
          \ ' <silent> <buffer> ' .
          \ (a:with_leader ? g:bullets_mapping_leader : '') .
          \ a:mapping .
          \ ' ' .
          \ a:action .
          \ '| endif'
  endif
endfun

augroup TextBulletsMappings
  autocmd!

  if g:bullets_set_mappings
    " Automatic bullets
    call s:add_local_mapping(1, 'imap', '<cr>', '<Plug>(bullets-newline)')
    call s:add_local_mapping(1, 'inoremap', '<C-cr>', '<cr>')

    call s:add_local_mapping(1, 'nmap', 'o', '<Plug>(bullets-newline)')

    " Renumber bullet list
    call s:add_local_mapping(1, 'vmap', 'gN', '<Plug>(bullets-renumber)')
    call s:add_local_mapping(1, 'nmap', 'gN', '<Plug>(bullets-renumber)')

    " Toggle checkbox
    call s:add_local_mapping(1, 'nmap', '<leader>x', '<Plug>(bullets-toggle-checkbox)')

    " Promote and Demote outline level
    call s:add_local_mapping(1, 'imap', '<C-t>', '<Plug>(bullets-demote)')
    call s:add_local_mapping(1, 'nmap', '>>', '<Plug>(bullets-demote)')
    call s:add_local_mapping(1, 'vmap', '>', '<Plug>(bullets-demote)')
    call s:add_local_mapping(1, 'imap', '<C-d>', '<Plug>(bullets-promote)')
    call s:add_local_mapping(1, 'nmap', '<<', '<Plug>(bullets-promote)')
    call s:add_local_mapping(1, 'vmap', '<', '<Plug>(bullets-promote)')
  end

  for s:custom_key_mapping in g:bullets_custom_mappings
    call call('<SID>add_local_mapping', [0] + s:custom_key_mapping)
  endfor
augroup END
" --------------------------------------------------------- }}}
let g:loaded_bullets = 1

