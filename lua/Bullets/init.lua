-- bullets.nvim
-- Author: Keith Miyake
-- Rewritten from https://github.com/dkarter/bullets.vim
-- License: GPLv3, MIT
-- Copyright (c) 2024 Keith Miyake
-- See LICENSE


-- --------------------------------------------
-- Setup
-- templated from <https://github.com/echasnovski/mini.nvim>
-- MIT License

-- Copyright (c) 2021 Evgeni Chasnovski

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
-- --------------------------------------------

local Bullets = {}
local H = {}

Bullets.setup = function(config)
  _G.Bullets = Bullets
  config = H.setup_config(config)
  H.apply_config(config)
end

Bullets.config = {
  colon_indent = true,
  delete_last_bullet = true,
  empty_buffers = true,
  file_types = { 'markdown', 'text', 'gitcommit' },
  line_spacing = 1,
  mappings = true,
  outline_levels = {'ROM','ABC', 'num', 'abc', 'rom', 'std*', 'std-', 'std+'},
  renumber = true,
  alpha = {
    len = 2,
  },
  checkbox = {
    nest = true,
    markers = ' .oOx',
    toggle_partials = true,
  },
}
H.default_config = Bullets.config

H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config

  vim.validate('config', config, 'table', true)
  config = vim.tbl_deep_extend('force', H.default_config, config or {})
  vim.validate('colon_indent', config.colon_indent, 'boolean', true)
  vim.validate('delete_last_bullet', config.delete_last_bullet, 'boolean', true)
  vim.validate('empty_buffers', config.empty_buffers, 'boolean', true)
  vim.validate('file_types', config.file_types, 'table', true)
  vim.validate('line_spacing', config.line_spacing, 'number', true)
  vim.validate('mappings', config.mappings, 'boolean', true)
  vim.validate('outline_levels', config.outline_levels, 'table', true)
  vim.validate('renumber', config.renumber, 'boolean', true)
  vim.validate('alpha', config.alpha, 'table', true)
  vim.validate('checkbox', config.checkbox, 'table', true)
  vim.validate('alpha.len', config.alpha.len, 'number', true)
  vim.validate('checkbox.nest', config.checkbox.nest, 'boolean', true)
  vim.validate('checkbox.markers', config.checkbox.markers, 'string', true)
  vim.validate('checkbox.toggle_partials', config.checkbox.toggle_partials, 'boolean', true)
  return config
end

H.apply_config = function(config)

  local power = config.alpha.len
  config.abc_max = -1
  while power >= 0 do
    config.abc_max = config.abc_max + 26 ^ power
    power = power - 1
  end
  Bullets.config = config

  vim.api.nvim_create_user_command('BulletDemote', function() Bullets.change_bullet_level(-1, 0) end, {})
  vim.api.nvim_create_user_command('BulletDemoteVisual', function() Bullets.change_bullet_level(-1, 1) end, {range = true})
  vim.api.nvim_create_user_command('BulletPromote', function() Bullets.change_bullet_level(1, 0) end, {})
  vim.api.nvim_create_user_command('BulletPromoteVisual', function() Bullets.change_bullet_level(1, 1) end, {range = true})
  vim.api.nvim_create_user_command('InsertNewBulletCR', function() Bullets.insert_new_bullet("cr") end, {})
  vim.api.nvim_create_user_command('InsertNewBulletO', function() Bullets.insert_new_bullet("o") end, {})
  vim.api.nvim_create_user_command('RenumberList', function() Bullets.renumber_whole_list() end, {})
  vim.api.nvim_create_user_command('RenumberSelection', function() Bullets.renumber_selection() end, {range = true})
  -- vim.api.nvim_create_user_command('SelectBullet', function() Bullets.select_bullet_item(vim.cmd.line('.')) end, {})
  -- vim.api.nvim_create_user_command('SelectBulletText', function() Bullets.select_bullet_text(vim.cmd.line('.')) end, {})
  vim.api.nvim_create_user_command('SelectCheckbox', function() Bullets.select_checkbox(false) end, {})
  vim.api.nvim_create_user_command('SelectCheckboxInside', function() Bullets.select_checkbox(true) end, {})
  vim.api.nvim_create_user_command('ToggleCheckbox', function() Bullets.toggle_checkboxes_nested() end, {})

  vim.api.nvim_set_keymap('i', '<Plug>(bullets-newline-cr)', '<C-O>:InsertNewBulletCR<cr>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('n', '<Plug>(bullets-newline-o)', ':InsertNewBulletO<cr>', {noremap = true, silent = true})
  -- vim.api.nvim_set_keymap('n', '<Plug>(bullets-newline)', ':InsertNewBullet<cr>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('v', '<Plug>(bullets-renumber)', ':RenumberSelection<cr>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('n', '<Plug>(bullets-renumber)', ':RenumberList<cr>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('n', '<Plug>(bullets-toggle-checkbox)', ':ToggleCheckbox<cr>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('i', '<Plug>(bullets-demote)', '<C-O>:BulletDemote<cr>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('n', '<Plug>(bullets-demote)', ':BulletDemote<cr>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('v', '<Plug>(bullets-demote)', ':BulletDemoteVisual<cr>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('i', '<Plug>(bullets-promote)', '<C-O>:BulletPromote<cr>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('n', '<Plug>(bullets-promote)', ':BulletPromote<cr>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('v', '<Plug>(bullets-promote)', ':BulletPromoteVisual<cr>', {noremap = true, silent = true})

  if config.mappings then
    vim.api.nvim_create_augroup('BulletMaps', {clear = true})
    H.buf_map('imap', '<cr>', '<Plug>(bullets-newline-cr)')
    -- H.buf_map('inoremap', '<C-CR>', '<CR>')
    H.buf_map('nmap', 'o', '<Plug>(bullets-newline-o)')
    H.buf_map('vmap', 'gN', '<Plug>(bullets-renumber)')
    H.buf_map('nmap', 'gN', '<Plug>(bullets-renumber)')
    H.buf_map('nmap', '<leader>x', '<Plug>(bullets-toggle-checkbox)')
    H.buf_map('imap', '<C-t>', '<Plug>(bullets-demote)')
    H.buf_map('nmap', '>>', '<Plug>(bullets-demote)')
    H.buf_map('vmap', '>', '<Plug>(bullets-demote)')
    H.buf_map('imap', '<C-d>', '<Plug>(bullets-promote)')
    H.buf_map('nmap', '<<', '<Plug>(bullets-promote)')
    H.buf_map('vmap', '<', '<Plug>(bullets-promote)')
  end

end

H.buf_map = function(mode, lhs, rhs)
  local fts = table.concat(Bullets.config.file_types,',')
  vim.api.nvim_create_autocmd('Filetype',{
    pattern = fts,
    group = 'BulletMaps',
    command = mode .. ' <silent> <buffer> ' .. lhs .. ' ' .. rhs
  })
  if Bullets.config.empty_buffers then
    vim.api.nvim_create_autocmd('BufEnter', {
      group = 'BulletMaps',
      command = 'if bufname("") == ""|' .. mode .. ' <silent> <buffer> ' .. lhs .. ' ' .. rhs .. '| endif'
    })
  end
end




H.define_bullet = function(match,btype,line_num)
  local bullet = {}
  if next(match) ~= nil then
    bullet.type = btype
    bullet.bullet_length = string.len(match[3])
    bullet.leading_space = match[4]
    bullet.bullet = match[5]
    bullet.checkbox_marker = type(match[6]) ~= "number" and match[6] or ""
    bullet.closure = type(match[7]) ~= "number" and match[7] or ""
    bullet.trailing_space = match[8]
    bullet.text_after_bullet = match[9]
    bullet.starting_at_line_num = line_num
  end
  return bullet
end

H.parse_bullet = function(line_num, input_text)
  local std_bullet_regex = '^((%s*)([%+%-%*%.])()()(%s+))(.*)'
  local checkbox_bullet_regex = '^((%s*)([%-%*%+]) %[([' .. Bullets.config.checkbox.markers .. ' xX])%]()(%s+))(.*)'
  local num_bullet_regex  = '^((%s*)(%d+)()([%.%)])(%s+))(.*)'
  local rom_bullet_regex  = '\\v\\C^((\\s*)(M{0,4}%(CM|CD|D?C{0,3})%(XC|XL|L?X{0,3})%(IX|IV|V?I{0,3})|m{0,4}%(cm|cd|d?c{0,3})%(xc|xl|l?x{0,3})%(ix|iv|v?i{0,3}))()(\\.|\\))(\\s+))(.*)'
  local max = tostring(Bullets.config.alpha.len)
  local az = "[%a]"
  local abc = ""
  for _ = 1, max do
    abc = abc .. az .. "?"
  end
  local abc_bullet_regex = '^((%s*)(' .. abc .. ')()([%.%)])(%s+))(.*)'

  local matches = {string.find(input_text, checkbox_bullet_regex)}

  if next(matches) ~= nil then
    return H.define_bullet(matches,'chk',line_num)
  end
  matches = {string.find(input_text, std_bullet_regex)}
  if next(matches) ~= nil then
    return H.define_bullet(matches,'std',line_num)
  end
  matches = {string.find(input_text, num_bullet_regex)}
  if next(matches) ~= nil then
    return H.define_bullet(matches,'num',line_num)
  end
  matches = vim.fn.matchlist(input_text, rom_bullet_regex)
  if next(matches) ~= nil then
    table.insert(matches, 1, 0)
    return H.define_bullet(matches,'rom',line_num)
  end
  matches = {string.find(input_text, abc_bullet_regex)}
  if next(matches) ~= nil then
    return H.define_bullet(matches,'abc',line_num)
  end

  return {}
end

H.closest_bullet_types = function(from_line_num, max_indent)
  local lnum = from_line_num
  local ltxt = vim.fn.getline(lnum)
  local curr_indent = vim.fn.indent(lnum)
  local bullet_kinds = H.parse_bullet(lnum, ltxt)

  if max_indent < 0 then
    return {}
  end

  -- Support for wrapped text bullets, even if the wrapped line is not indented
  -- It considers a blank line as the end of a bullet
  -- DEMO: http//raw.githubusercontent.com/dkarter/bullets.vim/master/img/wrapped-bullets.gif
  while lnum > 1 and (max_indent < curr_indent or next(bullet_kinds) == nil) and (curr_indent ~= 0 or next(bullet_kinds) ~= nil) and not string.match(ltxt,"^%s*$") do
    if next(bullet_kinds) ~= nil then
      lnum = lnum - Bullets.config.line_spacing
    else
      lnum = lnum - 1
    end
    ltxt = vim.fn.getline(lnum)
    bullet_kinds = H.parse_bullet(lnum, ltxt)
    curr_indent = vim.fn.indent(lnum)
  end
  return bullet_kinds
end

H.contains_type = function(bullet_types, type)
  for _, types in ipairs(bullet_types) do
    if type == types.type then
      return true
    end
  end

  return false
end

H.find_by_type = function(bullet_types, type)
  for _, bullet in ipairs(bullet_types) do
    if type == bullet.type then
      return bullet
    end
  end
  return {}
end

H.has_rom_or_abc = function(bullet_types)
  local has_rom = H.contains_type(bullet_types, 'rom')
  local has_abc = H.contains_type(bullet_types, 'abc')
  return has_rom or has_abc
end

H.has_chk_or_std = function(bullet_types)
  local has_chk = H.contains_type(bullet_types, 'chk')
  local has_std = H.contains_type(bullet_types, 'std')
  return has_chk or has_std
end

H.dec2abc = function(dec, islower)
  local a = 'A'
  if islower then
    a = 'a'
  end

  local rem = (dec - 1) % 26
  local abc = string.char(rem + a:byte())
  if dec <= 26 then
    return abc
  else
    return H.dec2abc((dec - 1)/ 26, islower) .. abc
  end
end

H.abc2dec = function(abc)
  local cba = string.lower(abc)
  local a = 'a'
  local abc1 = string.sub(cba, 1, 1)
  local dec = abc1:byte() - a:byte() + 1
  if string.len(cba) == 1 then
    return dec
  else
    return math.floor(26 ^ string.len(abc) - 1) * dec + H.abc2dec(string.sub(abc, 1, string.len(abc) - 1))
  end
end

H.resolve_rom_or_abc = function(bullet_types)
  local first_type = bullet_types
  local prev_search_starting_line = first_type.starting_at_line_num - Bullets.config.line_spacing
  local bullet_indent = vim.fn.indent(first_type.starting_at_line_num)
  local prev_bullet_types = H.closest_bullet_types(prev_search_starting_line, bullet_indent)

  while next(prev_bullet_types) ~= nil and bullet_indent <= vim.fn.indent(prev_search_starting_line) do
    prev_search_starting_line = prev_search_starting_line - Bullets.config.line_spacing
    prev_bullet_types = H.closest_bullet_types(prev_search_starting_line, bullet_indent)
  end

  if next(prev_bullet_types) == nil or bullet_indent > vim.fn.indent(prev_search_starting_line) then
    -- can't find previous bullet - so we probably have a rom i. bullet
    return H.find_by_type(bullet_types, 'rom')

  elseif #prev_bullet_types == 1 and H.has_rom_or_abc(prev_bullet_types) then
    -- previous bullet is conclusive, use it's type to continue
    if H.abc2dec(prev_bullet_types.bullet) - H.abc2dec(first_type.bullet) == 0 then
      return H.find_by_type(bullet_types, prev_bullet_types[1].type)
    end
  end
  if H.has_rom_or_abc(prev_bullet_types) then

    -- inconclusive - keep searching up recursively
    local prev_bullet = H.resolve_rom_or_abc(prev_bullet_types)
    return H.find_by_type(bullet_types, prev_bullet.type)

  else

    -- parent has unrelated bullet type, we'll go with rom
    return H.find_by_type(bullet_types, 'rom')
  end
end

H.resolve_chk_or_std = function(bullet_types)
  -- if it matches both regular and checkbox it is most likely a checkbox
  return H.find_by_type(bullet_types, 'chk')
end

H.resolve_bullet_type = function(bullet_types)
  if next(bullet_types) == nil then
    return {}
  elseif H.has_rom_or_abc(bullet_types) then
    return H.resolve_rom_or_abc(bullet_types)
  elseif H.has_chk_or_std(bullet_types) then
    return H.resolve_chk_or_std(bullet_types)
  else
    return bullet_types  -- assume the first bullet type
  end
end

-- Roman numeral conversion {{{
-- <http//gist.github.com/efrederickson/4080372>
H.num_to_rom = function(s, islower) --s = tostring(s)
  local numbers = { 1, 5, 10, 50, 100, 500, 1000 }
  local chars = { "i", "v", "x", "l", "c", "d", "m" }
  if not s or s ~= s then error"Unable to convert to number" end
  if s == math.huge then error"Unable to convert infinity" end
  s = math.floor(s)
  if s <= 0 then return s end
  local ret = ""
  for i = #numbers, 1, -1 do
    local num = numbers[i]
    while s - num >= 0 and s > 0 do
      ret = ret .. chars[i]
      s = s - num
    end
    for j = 1, i - 1 do
      local n2 = numbers[j]
      if s - (num - n2) >= 0 and s < num and s > 0 and num - n2 ~= n2 then
        ret = ret .. chars[j] .. chars[i]
        s = s - (num - n2)
        break
      end
    end
  end
  if islower then
    return ret
  else
    return string.upper(ret)
  end
end

H.rom_to_num = function(s)
  local map = {
    i = 1,
    v = 5,
    x = 10,
    l = 50,
    c = 100,
    d = 500,
    m = 1000,
  }
  s = string.lower(s)
  local ret = 0
  local i = 1
  while i <= string.len(s) do
    --for i = 1, len() do
    local c = string.sub(s, i, i)
    if c ~= " " then -- allow spaces
      local m = map[c] or error("Unknown Roman Numeral '" .. c .. "'")

      local next = string.sub(s, i + 1, i + 1)
      local nextm = map[next]

      if next and nextm then
        if nextm > m then
          -- if string[i] < string[i + 1] then result += string[i + 1] - string[i]
          -- This is used instead of programming in IV = 4, IX = 9, etc, because it is
          -- more flexible and possibly more efficient
          ret = ret + (nextm - m)
          i = i + 1
        else
          ret = ret + m
        end
      else
        ret = ret + m
      end
    end
    i = i + 1
  end
  return ret
end
-- }}}

H.next_rom_bullet = function(bullet)
  local islower = bullet.bullet == string.lower(bullet.bullet)
  return H.num_to_rom(H.rom_to_num(bullet.bullet) + 1, islower)
end

H.next_abc_bullet = function(bullet)
  local islower = bullet.bullet == string.lower(bullet.bullet)
  return H.dec2abc(H.abc2dec(bullet.bullet) + 1, islower)
end

H.next_num_bullet = function(bullet)
  return bullet.bullet + 1
end

H.next_chk_bullet = function(bullet)
  return string.sub(bullet.bullet, 1, 1) .. " [" .. string.sub(Bullets.config.checkbox.markers, 1, 1) .. "]"
end

H.next_bullet_str = function(bullet)
  local bullet_type = bullet.type
  local next_bullet_marker = ""

  if bullet_type == "rom" then
    next_bullet_marker = H.next_rom_bullet(bullet)
  elseif bullet_type == "abc" then
    next_bullet_marker = H.next_abc_bullet(bullet)
  elseif bullet_type == "num" then
    next_bullet_marker = H.next_num_bullet(bullet)
  elseif bullet_type == "chk" then
    next_bullet_marker = H.next_chk_bullet(bullet)
  else
    next_bullet_marker = bullet.bullet
  end
  return bullet.leading_space .. next_bullet_marker .. bullet.closure  .. bullet.trailing_space
end

H.line_ends_in_colon = function(lnum)
  local line = vim.fn.getline(lnum)
  return string.sub(line, string.len(line)) == ":"
end

H.change_line_bullet_level = function(direction, lnum)
  local curr_line = H.parse_bullet(lnum, vim.fn.getline(lnum))

  if direction == 1 then
    if next(curr_line) ~= nil and vim.fn.indent(lnum) == 0 then
      -- Promoting a bullet at the highest level will delete the bullet
      vim.fn.setline(lnum, curr_line[0].text_after_bullet)
      return
    else
      vim.cmd(lnum .. "normal! <<")
    end
  else
    vim.cmd(lnum .. "normal! >>")
  end

  if next(curr_line) == nil then
    -- If the current line is not a bullet then don't do anything else.
    -- TODO: feedkeys
    local insert_mode = vim.fn.mode() == 'i'

    if insert_mode then
      vim.cmd("startinsert!")
    end

    local keys = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
    vim.api.nvim_feedkeys(keys, 'n', true)

    return
  end

  local curr_indent = vim.fn.indent(lnum)
  local curr_bullet = H.closest_bullet_types(lnum, curr_indent)
  curr_bullet = H.resolve_bullet_type(curr_bullet)

  curr_line = curr_bullet.starting_at_line_num
  local closest_bullet = H.closest_bullet_types(curr_line - Bullets.config.line_spacing, curr_indent)
  closest_bullet = H.resolve_bullet_type(closest_bullet)

  if next(closest_bullet) == nil then
    -- If there is no parent/sibling bullet then this bullet shouldn't change.
    return
  end

  local islower = closest_bullet.bullet == string.lower(closest_bullet.bullet)
  local closest_indent = vim.fn.indent(closest_bullet.starting_at_line_num)
  local closest_type = islower and closest_bullet.type or string.upper(closest_bullet.type)
  if closest_bullet.type == 'std' then
    -- Append the bullet marker to the type, e.g., 'std*'
   closest_type = closest_type .. closest_bullet.bullet
  end

  local bullets_outline_levels = Bullets.config.outline_levels
  local closest_index = -1
  for i, j in ipairs(bullets_outline_levels) do
    if closest_type == j then
      closest_index = i
      break
    end
  end
  if closest_index == -1 then
    -- We are in a list using markers that aren't specified in
    -- bullets_outline_levels so we shouldn't try to change the current
    -- bullet.
    return
  end

  local bullet_str = ""
  if (curr_indent == closest_indent) then
    -- The closest bullet is a sibling so the current bullet should
    -- increment to the next bullet marker.

    -- local next_bullet = H.next_bullet_str(closest_bullet)
    -- bullet_str = pad_to_length(next_bullet, closest_bullet.bullet_length) .. curr_bullet.text_after_bullet
    bullet_str = H.next_bullet_str(closest_bullet) .. curr_bullet.text_after_bullet

  elseif closest_index + 1 > #bullets_outline_levels and curr_indent > closest_indent then
    -- The closest bullet is a parent and its type is the last one defined in
    -- g:bullets_outline_levels so keep the existing bullet.
    -- TODO: Might make an option for whether the bullet should stay or be
    -- deleted when demoting past the end of the defined bullet types.
    return
  elseif closest_index + 1 <= #bullets_outline_levels or curr_indent < closest_indent then
    -- The current bullet is a child of the closest bullet so figure out
    -- what bullet type it should have and set its marker to the first
    -- character of that type.

    local next_type = bullets_outline_levels[closest_index + 1]
    local next_islower = next_type == string.lower(next_type)
    -- local trailing_space = ' '
    curr_bullet.closure = closest_bullet.closure

    -- set the bullet marker to the first character of the new type
    local next_num
    if next_type == 'rom' or next_type == 'ROM' then
      next_num = H.num_to_rom(1, next_islower)
    elseif next_type == 'abc' or next_type == 'ABC' then
      next_num = H.dec2abc(1, next_islower)
    elseif next_type == 'num' then
      next_num = '1'
    else
      -- standard bullet; the last character of next_type contains the bullet
      -- symbol to use
      next_num = string.sub(next_type, -1)
      curr_bullet.closure = ''
    end

    bullet_str = curr_bullet.leading_space .. next_num .. curr_bullet.closure .. curr_bullet.trailing_space .. curr_bullet.text_after_bullet

  else
    -- We're outside of the defined outline levels
    bullet_str = curr_bullet.leading_space .. curr_bullet.text_after_bullet
  end

  -- Apply the new bullet
  vim.fn.setline(lnum, bullet_str)
end

Bullets.change_bullet_level = function(direction, is_visual)
  -- Changes the bullet level for each of the selected lines
  local sel = H.get_selection(is_visual)
  for lnum = sel.start_line, sel.end_line do
    H.change_line_bullet_level(direction, lnum)
  end
  if Bullets.config.renumber then
    -- Pass the current visual selection so that it gets reset after
    -- renumbering the list.
    Bullets.renumber_whole_list()
  end
  H.set_selection(sel)
end

H.first_bullet_line = function(line_num, min_indent)
  -- returns the line number of the first bullet in the list containing the
  -- given line number, up to the first blank line
  -- returns -1 if lnum is not in a list
  -- Optional argument: only consider bullets at or above this indentation
  local indent = min_indent or 0
  if indent < 0 then
    -- sanity check
    return -1
  end
  local first_line = line_num
  local lnum = line_num - Bullets.config.line_spacing
  local curr_indent = vim.fn.indent(lnum)
  local bullet_kinds = H.closest_bullet_types(lnum, curr_indent)

  while lnum >= 1 and curr_indent >= indent and next(bullet_kinds) ~= nil do
    first_line = lnum
    lnum = lnum - Bullets.config.line_spacing
    curr_indent = vim.fn.indent(lnum)
    bullet_kinds = H.closest_bullet_types(lnum, curr_indent)
  end
  return first_line
end

H.last_bullet_line = function(line_num, min_indent)
  -- returns the line number of the last bullet in the list containing the
  -- given line number, down to the end of the list
  -- returns -1 if lnum is not in a list
  -- Optional argument: only consider bullets at or above this indentation
  local indent = min_indent or 0
  local lnum = line_num
  local buf_end = vim.fn.line('$')
  local last_line = -1
  local curr_indent = vim.fn.indent(lnum)
  local bullet_kinds = H.closest_bullet_types(lnum, curr_indent)
  local blank_lines = 0
  local list_end = false

  if indent < 0 then
    -- sanity check
    return -1
  end

  while lnum <= buf_end and not list_end and curr_indent >= indent do
    if next(bullet_kinds) ~= nil then
      last_line = lnum
      blank_lines = 0
    else
      blank_lines = blank_lines + 1
      list_end = blank_lines >= Bullets.config.line_spacing
    end
    lnum = lnum + 1
    curr_indent = vim.fn.indent(lnum)
    bullet_kinds = H.closest_bullet_types(lnum, curr_indent)
  end
  return last_line
end

H.get_selection = function(is_visual)
  local sel = {}
  local mode = ""
  if is_visual ~= 0 then
    mode = vim.fn.visualmode()
  end
  if mode == "v" or mode == "V" or mode == "\\<C-v>" then
    -- local start_line, start_col = vim.fn.getpos("'<")[2], vim.fn.getpos("'>")[3]
    local start_line = { unpack(vim.fn.getpos("'<"), 2, 3) }
    sel.start_line = start_line[1]
    sel.start_offset = string.len(vim.fn.getline(sel.start_line)) - start_line[2]
    -- local end_line, end_col = vim.fn.getpos("'>")[2], vim.fn.getpos("'>")[3]
    local end_line = { unpack(vim.fn.getpos("'>"), 2, 3) }
    sel.end_line = end_line[1]
    sel.end_offset = string.len(vim.fn.getline(sel.end_line)) - end_line[2]
    sel.visual_mode = mode
  else
    sel.start_line = vim.fn.line(".")
    sel.start_offset = string.len(vim.fn.getline(sel.start_line)) - vim.fn.col(".")
    sel.end_line = sel.start_line
    sel.end_offset = sel.start_offset
    sel.visual_mode = ""
  end
  return sel
end

H.set_selection = function(sel)
  local start_col = string.len(vim.fn.getline(sel.start_line)) - sel.start_offset
  local end_col = string.len(vim.fn.getline(sel.end_line)) - sel.end_offset
  vim.fn.cursor(sel.start_line, start_col)
  if sel.start_line ~= sel.end_line or start_col ~= end_col then
    -- if sel.visual_mode == "<C-v>" then
    -- broken, need to figure out how to escape \<C-v>
    --   vim.cmd("normal! <C-v>")
    -- else
    if sel.visual_mode == "V" or sel.visual_mode == "v" then
      vim.cmd("normal! v")
    end
    -- end
    vim.fn.cursor(sel.end_line, end_col)
  end
end

-- Checkboxes --------------------------------------------- {{{
H.find_checkbox_position = function(lnum)
  local line_text = vim.fn.getline(lnum)
  return vim.fn.matchend(line_text, "\\v\\s*(\\*|-) \\[") + 1
end

Bullets.select_checkbox = function(inner)
  local lnum = vim.fn.line('.')
  local checkbox_col = H.find_checkbox_position(lnum)

  if checkbox_col then
    vim.fn.setpos('.', {0, lnum, checkbox_col})

    -- decide if we need to select the whole checkbox with brackets or just the
    -- inside of it
    if inner then
      vim.cmd("normal! vi[")
    else
      vim.cmd("normal! va[")
    end
  end
end

H.set_checkbox = function(lnum, marker)
  local curline = vim.fn.getline(lnum)
  local initpos = vim.fn.getpos('.')
  local pos = H.find_checkbox_position(lnum)
  if pos >= 0 then
    local front = string.sub(curline, 1, pos - 1)
    local back = string.sub(curline, pos + 1)
    vim.fn.setline(lnum, front .. marker .. back)
    vim.fn.setpos('.', initpos)
  end
end

H.toggle_checkbox = function(lnum)
  -- Toggles the checkbox on line a:lnum.
  -- Returns the resulting status (1) checked, (0) unchecked, (-1) unchanged
  local indent = vim.fn.indent(lnum)
  local bullet = H.closest_bullet_types(lnum, indent)
  bullet = H.resolve_bullet_type(bullet)
  local checkbox_content = bullet.checkbox_marker
  if next(bullet) == nil or bullet['checkbox_marker'] == nil then
    return -1
  end

  local checkbox_markers = Bullets.config.checkbox.markers
  -- get markers that aren't empty or fully checked
  local partial_markers = string.sub(checkbox_markers, 2, #checkbox_markers - 1)
  local marker = string.sub(checkbox_markers, 1, 1)
  if Bullets.config.checkbox.toggle_partials and string.find(partial_markers, checkbox_content) ~= nil then
    -- Partially complete
    if Bullets.config.checkbox.toggle_partials then
      marker = string.sub(checkbox_markers, -1)
    end
  elseif checkbox_content == string.sub(checkbox_markers, 1, 1) then
    marker = string.sub(checkbox_markers, -1)
    -- marker = string.sub(checkbox_markers,#checkbox_markers, 1)
  elseif string.find(checkbox_content, 'x') ~= nil or string.find(checkbox_content, 'X') ~= nil or string.find(checkbox_content, string.sub(checkbox_markers, -1)) ~= nil then
    marker = string.sub(checkbox_markers, 1, 1)
  else
    return -1
  end

  H.set_checkbox(lnum, marker)
  return marker == string.sub(checkbox_markers, #checkbox_markers, 1)
end

H.get_sibling_line_numbers = function(lnum)
  -- returns a list with line numbers of the sibling bullets with the same
  -- indentation as a:indent, starting from the given line number, a:lnum
  local indent = vim.fn.indent(lnum)
  local first_sibling = H.first_bullet_line(lnum, indent)
  local last_sibling = H.last_bullet_line(lnum, indent)
  local siblings = {}
  for l = first_sibling, last_sibling do
    if vim.fn.indent(l) == indent then
      local bullet = H.parse_bullet(l, vim.fn.getline(l))
      if next(bullet) ~= nil then
        table.insert(siblings, l)
      end
    end
  end
  return siblings
end

H.get_children_line_numbers = function(line_num)
  -- returns a list with line numbers of the immediate children bullets with
  -- indentation greater than line a:lnum

  -- sanity check
  if line_num < 1 then
    return {}
  end

  -- find the first child (if any) so we can figure out the indentation for the
  -- rest of the children
  local lnum = line_num + 1
  local indent = vim.fn.indent(lnum)
  local buf_end = vim.fn.line('$')
  local curr_indent = indent(lnum)
  local bullet_kinds = H.closest_bullet_types(lnum, curr_indent)
  local child_lnum = 0
  local blank_lines = 0

  while lnum <= buf_end and child_lnum == 0 do
    if next(bullet_kinds) ~= nil and curr_indent > indent then
      child_lnum = lnum
    else
      blank_lines = blank_lines + 1
      if blank_lines >= Bullets.config.line_spacing then
        child_lnum = -1
      else
        child_lnum = 0
      end
    end
    lnum = lnum + 1
    curr_indent = indent(lnum)
    bullet_kinds = H.closest_bullet_types(lnum, curr_indent)
  end

  if child_lnum > 0 then
    return H.get_sibling_line_numbers(child_lnum)
  else
    return {}
  end
end

H.sibling_checkbox_status = function(lnum)
  -- Returns the marker corresponding to the proportion of siblings that are
  -- completed.
  local siblings = H.get_sibling_line_numbers(lnum)
  local num_siblings = #siblings
  local checked = 0
  local checkbox_markers = Bullets.config.checkbox.markers
  for _, l in ipairs(siblings) do
    local indent = vim.fn.indent(l)
    local bullet = H.closest_bullet_types(l, indent)
    bullet = H.resolve_bullet_type(bullet)
    if next(bullet) ~= nil and bullet.checkbox_marker ~= "" then
      if string.find(string.sub(checkbox_markers, 2, #checkbox_markers), bullet.checkbox_marker) ~= nil then
        -- Checked
        checked = checked + 1
      end
    end
  end
  local divisions = #checkbox_markers - 1
  local completion = 1 + math.floor(divisions * checked / num_siblings)
  return string.sub(checkbox_markers, completion, completion)
end

H.get_parent = function(lnum)
  -- returns the parent bullet of the given line number, lnum, with indentation
  -- at or below the given indent.
  -- if there is no parent, returns an empty dictionary
  local indent = vim.fn.indent(lnum)
  if indent < 0 then
    return {}
  end
  local parent = H.closest_bullet_types(lnum, indent - 1)
  parent = H.resolve_bullet_type(parent)
  return parent
end

H.set_parent_checkboxes = function(lnum, marker)
  -- set the parent checkbox of line a:lnum, as well as its parents, based on
  -- the marker passed in a:marker
  if not Bullets.config.checkbox.nest then
    return
  end

  local parent = H.get_parent(lnum)
  if next(parent) ~= nil and parent.type == 'chk' then
    -- Check for siblings' status
    local pnum = parent.starting_at_line_num
    H.set_checkbox(pnum, marker)
    H.set_parent_checkboxes(pnum, H.sibling_checkbox_status(pnum))
  end
end

H.set_child_checkboxes = function(lnum, checked)
  -- set the children checkboxes of line a:lnum based on the value of a:checked
  -- 0: unchecked, 1: checked, other: do nothing
  if not Bullets.config.checkbox.nest or not (checked == 0 or checked == 1) then
    return
  end

  local children = H.get_children_line_numbers(lnum)
  if next(children) ~= nil then
    local checkbox_markers = Bullets.config.checkbox.markers
    for child in children do
      local marker
      if checked then
        marker = string.sub(checkbox_markers, string.len(checkbox_markers), 1)
      else
        marker = string.sub(checkbox_markers, 1, 1)
      end
      H.set_checkbox(child, marker)
      H.set_child_checkboxes(child, checked)
    end
  end
end

Bullets.toggle_checkboxes_nested = function()
  -- toggle checkbox on the current line, as well as its parents and children
  local lnum = vim.fn.line('.')
  local indent = vim.fn.indent(lnum)
  local bullet = H.closest_bullet_types(lnum, indent)
  bullet = H.resolve_bullet_type(bullet)

  -- Is this a checkbox? Do nothing if it's not, otherwise toggle the checkbox
  if next(bullet) == nil or bullet.type ~= 'chk' then
    return
  end

  local checked = H.toggle_checkbox(lnum)

  if Bullets.config.checkbox.nest then
    -- Toggle children and parents
    local completion_marker = H.sibling_checkbox_status(lnum)
    H.set_parent_checkboxes(lnum, completion_marker)

    -- Toggle children
    if checked then
      H.set_child_checkboxes(lnum, checked)
    end
  end
end

-- Checkboxes --------------------------------------------- }}}

-- Renumbering --------------------------------------------- {{{
H.get_level = function(bullet)
  if next(bullet) == nil or bullet.type ~= 'std' then
    return 0
  else
    return string.len(bullet.bullet)
  end
end

Bullets.renumber_selection = function()
  local sel = H.get_selection(1)
  Bullets.renumber_lines(sel.start_line, sel.end_line)
  H.set_selection(sel)
end

Bullets.renumber_lines = function(start_ln, end_ln)
  local prev_indent = -1
  local list = {}  -- stores all the info about the current outline/list

  for nr = start_ln, end_ln do
    local indent = vim.fn.indent(nr)
    local bullet = H.closest_bullet_types(nr, indent)
    bullet = H.resolve_bullet_type(bullet)
    local curr_level = H.get_level(bullet)
    if curr_level > 1 then
      -- then it's an AsciiDoc list and shouldn't be renumbered
      break
    end

    if next(bullet) ~= nil and bullet.starting_at_line_num == nr then
      -- skip wrapped lines and lines that aren't bullets
      if (indent > prev_indent or list[indent] == nil) and bullet.type ~= 'chk' and bullet.type ~= 'std' then
        if list[indent] == nil then
          if bullet.type == 'num' then
            list[indent] = {index = bullet.bullet}
          elseif bullet.type == 'rom' then
            list[indent] = {index = H.rom_to_num(bullet.bullet)}
          elseif bullet.type == 'abc' then
            list[indent] = {index = H.abc2dec(bullet.bullet)}
          end
        end

        -- use the first bullet at this level to define the bullet type for
        -- subsequent bullets at the same level. Needed to normalize bullet
        -- types when there are multiple types of bullets at the same level.
        list[indent].islower = bullet.bullet == string.lower(bullet.bullet)
        list[indent].type = bullet.type
        list[indent].bullet = bullet.bullet  -- for standard bullets
        list[indent].closure = bullet.closure  -- normalize closures
        list[indent].trailing_space = bullet.trailing_space
      else
        if bullet.type ~= 'chk' and bullet.type ~= 'std' then
        if list[indent] == nil then
          -- list[indent] = {index = 1}
          if bullet.type == 'num' then
            list[indent] = {index = bullet.bullet}
          elseif bullet.type == 'rom' then
            list[indent] = {index = H.rom_to_num(bullet.bullet)}
          elseif bullet.type == 'abc' then
            list[indent] = {index = H.abc2dec(bullet.bullet)}
          end
        end
          list[indent].index = list[indent].index + 1
        end

        if indent < prev_indent then
          -- Reset the numbering on all all child items. Needed to avoid continuing
          -- the numbering from earlier portions of the list with the same bullet
          -- type in some edge cases.
          for key, _ in pairs(list) do
            if key > indent then
              list[key] = nil
            end
          end
        end
      end

      prev_indent = indent

      if list[indent] ~= nil then
        local bullet_num = list[indent].index
        local new_bullet = ""
        if bullet.type ~= 'chk' and bullet.type ~= 'std' then
          if list[indent].type == 'rom' then
            bullet_num = H.num_to_rom(list[indent].index, list[indent].islower)
          elseif list[indent].type == 'abc' then
            bullet_num = H.dec2abc(list[indent].index, list[indent].islower)
          end

          new_bullet = bullet_num .. list[indent].closure .. list[indent].trailing_space
          -- if list[indent].index > 1 then
          --   new_bullet = pad_to_length(new_bullet, list[indent].pad_len)
          -- end
          -- list[indent].pad_len = string.len(new_bullet)
          local renumbered_line = bullet.leading_space .. new_bullet .. bullet.text_after_bullet
          vim.fn.setline(nr, renumbered_line)
        elseif bullet.type == 'chk' then
          -- Reset the checkbox marker if it already exists, or blank otherwise
          local marker = ' '
          if bullet.checkbox_marker ~= nil then
            marker = bullet.checkbox_marker
          end
          H.set_checkbox(nr, marker)
        end
      end
    end
  end
end

Bullets.renumber_whole_list = function(start_pos, end_pos)
  -- Renumbers the whole list containing the cursor.
  -- Does not renumber across blank lines.
  local first_line = H.first_bullet_line(vim.fn.line('.'))
  local last_line = H.last_bullet_line(vim.fn.line('.'))
  if first_line > 0 and last_line > 0 then
    Bullets.renumber_lines(first_line, last_line)
  end
end

Bullets.insert_new_bullet = function(trigger)
  local curr_line_num = vim.fn.line('.')
  local cursor_pos = vim.fn.getcurpos('.')
  local line_text = vim.fn.getline('.')
  local next_line_num = curr_line_num + Bullets.config.line_spacing
  local curr_indent = vim.fn.indent(curr_line_num)
  local bullet_types = H.closest_bullet_types(curr_line_num, curr_indent)
  -- need to find which line starts the previous bullet started at and start
  -- searching up from there
  local send_return = true
  local normal_mode = vim.fn.mode() == 'n'
  local indent_next = H.line_ends_in_colon(curr_line_num) and Bullets.config.colon_indent
  local next_bullet_list = {}

  -- check if current line is a bullet and we are at the end of the line (for
  -- insert mode only)
  if next(bullet_types) ~= nil then
    local bullet = H.resolve_bullet_type(bullet_types)
    local is_at_eol = string.len(vim.fn.getline('.')) + 1 == vim.fn.col('.')
    if bullet ~= nil and next(bullet) ~= nil and (normal_mode or is_at_eol) then
      -- was any text entered after the bullet?
      if bullet.text_after_bullet == '' then
        -- We don't want to create a new bullet if the previous one was not used,
        -- instead we want to delete the empty bullet - like word processors do
        if Bullets.config.delete_last_bullet then
          vim.fn.setline(curr_line_num, '')
          send_return = false
        end
      elseif not (bullet.type == 'abc' and H.abc2dec(bullet.bullet) + 1 > Bullets.config.abc_max) then
        -- get text after cursor
        local text_after_cursor = ''
        if string.len(vim.fn.getline('.')) > vim.fn.col('.') and trigger == 'cr' then
          text_after_cursor = string.sub(line_text, cursor_pos[3])
          vim.fn.setline('.', string.sub(line_text,1,cursor_pos[3] - 1))
        end

        local next_bullet = H.next_bullet_str(bullet) .. text_after_cursor
        -- if bullet.type == 'chk' then
        next_bullet_list = {next_bullet}
        -- else
        --   next_bullet_list = {pad_to_length(next_bullet, bullet.bullet_length)}
        -- end

        -- prepend blank lines if desired
        if Bullets.config.line_spacing > 1 then
          for i = 1,Bullets.config.line_spacing do
            table.insert(next_bullet_list, i, '')
          end
        end


        -- insert next bullet
        vim.fn.append(curr_line_num, next_bullet_list)

        -- go to next line after the new bullet
        local col = string.len(vim.fn.getline(next_line_num)) + 1
        vim.fn.setpos('.', {0, next_line_num, col})

        -- indent if previous line ended in a colon
        if indent_next then
          -- demote the new bullet
          H.change_line_bullet_level(-1, next_line_num)
          -- reset cursor position after indenting
          col = string.len(vim.fn.getline(next_line_num)) + 1
          vim.fn.setpos('.', {0, next_line_num, col})
        elseif Bullets.config.renumber then
          Bullets.renumber_whole_list()
        end
      end
      send_return = false
    end
  end

  if send_return then
    if trigger == "cr" and normal_mode then
      vim.cmd('startinsert')
    elseif trigger == 'o' then
      vim.cmd('startinsert!')
    end
    local keys = vim.api.nvim_replace_termcodes('<CR>', true, false, true)
    vim.api.nvim_feedkeys(keys, 'n', true)
  elseif trigger == 'o' then
    vim.cmd('startinsert!')
  end

  -- need to return a string since we are in insert mode calling with <C-R>=
  return ''
end

return Bullets
