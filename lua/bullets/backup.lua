local power = vim.api.nvim_get_var("bullets_max_alpha_characters")
local abc_max = -1
while power >= 0 do
  abc_max = abc_max + 26 ^ power
  power = power - 1
end

local function define_bullet(match,btype,line_num)
  local bullet = {}
  if next(match) ~= nil then
    bullet.type = btype
    bullet.bullet_length = string.len(match[2])
    bullet.leading_space = match[3]
    bullet.bullet = match[4]
    bullet.checkbox_marker = match[5]
    bullet.closure = match[6]
    bullet.trailing_space = match[7]
    bullet.text_after_bullet = match[8]
    bullet.starting_at_line_num = line_num
  end
  return bullet
end

local function parse_bullet(line_num, input_text)
  local std_bullet_regex = '\\v(^(\\s*)(-|\\*+|\\.+|#\\.|\\+|\\\\item)()()(\\s+))(.*)'
  local checkbox_bullet_regex = '\\v(^(\\s*)([-\\*] \\[([' .. vim.api.nvim_get_var("bullets_checkbox_markers") .. ' xX])?\\])()(\\s+))(.*)'
  local num_bullet_regex  = '\\v^((\\s*)(\\d+)()(\\.|\\))(\\s+))(.*)'
  local rom_bullet_regex  = '\\v\\C^((\\s*)(M{0,4}%(CM|CD|D?C{0,3})%(XC|XL|L?X{0,3})%(IX|IV|V?I{0,3})|m{0,4}%(cm|cd|d?c{0,3})%(xc|xl|l?x{0,3})%(ix|iv|v?i{0,3}))()(\\.|\\))(\\s+))(.*)'
  local max = tostring(vim.api.nvim_get_var("bullets_max_alpha_characters"))
  local abc_bullet_regex = '\\v^((\\s*)(\\u{1,' .. max .. '}|\\l{1,' .. max .. '})()(\\.|\\))(\\s+))(.*)'
  print(abc_bullet_regex)

  local bullets = {}
  local matches = vim.fn.matchlist(input_text, std_bullet_regex)
  if next(matches) ~= nil then
    table.insert(bullets, define_bullet(matches,'std',line_num))
  end
  if next(matches) == nil then
    matches = vim.fn.matchlist(input_text, abc_bullet_regex)
    table.insert(bullets, define_bullet(matches,'abc',line_num))
  end
  if next(matches) == nil then
    matches = vim.fn.matchlist(input_text, checkbox_bullet_regex)
    table.insert(bullets, define_bullet(matches,'chk',line_num))
  end
  if next(matches) == nil then
    matches = vim.fn.matchlist(input_text, num_bullet_regex)
    table.insert(bullets, define_bullet(matches,'num',line_num))
  end
  if next(matches) == nil then
    matches = vim.fn.matchlist(input_text, rom_bullet_regex)
    table.insert(bullets, define_bullet(matches,'rom',line_num))
  end

  return bullets
end

local function closest_bullet_types(from_line_num, max_indent)
  local lnum = from_line_num
  local ltxt = vim.fn.getline(lnum)
  local curr_indent = vim.fn.indent(lnum)
  local bullet_kinds = parse_bullet(lnum, ltxt)

  if max_indent < 0 then
    return {}
  end

  -- Support for wrapped text bullets, even if the wrapped line is not indented
  -- It considers a blank line as the end of a bullet
  -- DEMO: http//raw.githubusercontent.com/dkarter/bullets.vim/master/img/wrapped-bullets.gif
  while lnum > 1 and (max_indent < curr_indent or next(bullet_kinds) == nil) and (curr_indent ~= 0 or next(bullet_kinds) ~= nil or string.match(ltxt,"^%s+$") or ltxt == "") do
    if next(bullet_kinds) ~= nil then
      lnum = lnum - vim.api.nvim_get_var("bullets_line_spacing")
    else
      lnum = lnum - 1
    end
    ltxt = vim.fn.getline(lnum)
    bullet_kinds = parse_bullet(lnum, ltxt)
    curr_indent = vim.fn.indent(lnum)
  end

  return bullet_kinds
end

local function contains_type(bullet_types, type)
  for _, types in ipairs(bullet_types) do
    if type == types.bullet_type then
      return true
    end
  end

  return false
end

local function find_by_type(bullet_types, type)
  for _, bullet in ipairs(bullet_types) do
    if type == bullet.bullet_type then
      return bullet
    end
  end
  return {}
end

local function has_rom_and_abc(bullet_types)
  local has_rom = contains_type(bullet_types, 'rom')
  local has_abc = contains_type(bullet_types, 'abc')
  return has_rom and has_abc
end

local function has_rom_or_abc(bullet_types)
  local has_rom = contains_type(bullet_types, 'rom')
  local has_abc = contains_type(bullet_types, 'abc')
  return has_rom or has_abc
end

local function has_chk_and_std(bullet_types)
  local has_chk = contains_type(bullet_types, 'chk')
  local has_std = contains_type(bullet_types, 'std')
  return has_chk and has_std
end

local function resolve_rom_or_abc(bullet_types)
  local first_type = bullet_types[1]
  local prev_search_starting_line = first_type.starting_at_line_num - vim.api.nvim_get_var("bullets_line_spacing")
  local bullet_indent = vim.fn.indent(first_type.starting_at_line_num)
  local prev_bullet_types = closest_bullet_types(prev_search_starting_line, bullet_indent)

  while next(prev_bullet_types) ~= nil and bullet_indent <= vim.fn.indent(prev_search_starting_line) do
    prev_search_starting_line = prev_search_starting_line - vim.api.nvim_get_var("bullets_line_spacing")
    prev_bullet_types = closest_bullet_types(prev_search_starting_line, bullet_indent)
  end

  if next(prev_bullet_types) == nil or bullet_indent > vim.fn.indent(prev_search_starting_line) then
    -- can't find previous bullet - so we probably have a rom i. bullet
    return find_by_type(bullet_types, 'rom')

  elseif #prev_bullet_types == 1 and has_rom_or_abc(prev_bullet_types) then
    -- previous bullet is conclusive, use it's type to continue
    return find_by_type(bullet_types, prev_bullet_types[1].bullet_type)

  elseif has_rom_and_abc(prev_bullet_types) then

    -- inconclusive - keep searching up recursively
    local prev_bullet = resolve_rom_or_abc(prev_bullet_types)
    return find_by_type(bullet_types, prev_bullet.bullet_type)

  else

    -- parent has unrelated bullet type, we'll go with rom
    return find_by_type(bullet_types, 'rom')
  end
end

local function resolve_chk_or_std(bullet_types)
  -- if it matches both regular and checkbox it is most likely a checkbox
  return find_by_type(bullet_types, 'chk')
end

local function resolve_bullet_type(bullet_types)
  if next(bullet_types) == nil then
    return {}
  elseif #bullet_types == 2 and has_rom_and_abc(bullet_types) then
    return resolve_rom_or_abc(bullet_types)
  elseif #bullet_types == 2 and has_chk_and_std(bullet_types) then
    return resolve_chk_or_std(bullet_types)
  else
    return bullet_types[1]
  end
end

-- Roman numeral conversion {{{
-- <http//gist.github.com/efrederickson/4080372>
local map = {
    i = 1,
    v = 5,
    x = 10,
    l = 50,
    c = 100,
    d = 500,
    m = 1000,
}
local numbers = { 1, 5, 10, 50, 100, 500, 1000 }
local chars = { "i", "v", "x", "l", "c", "d", "m" }

local function num_to_rom(s, islower) --s = tostring(s)
  -- s = tonumber(s)
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
    --for j = i - 1, 1, -1 do
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

local function rom_to_num(s)
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

local function next_rom_bullet(bullet)
  local islower = bullet.bullet == string.lower(bullet.bullet)
  return num_to_rom(rom_to_num(bullet.bullet) + 1, islower)
end

local dec2abc  -- predefine for recursion
dec2abc = function(dec, islower)
  local a = 'A'
  if islower then
    a = 'a'
  end

  local rem = (dec - 1) % 26
  local abc = string.char(rem + a:byte())
  if dec <= 26 then
    return abc
  else
    return dec2abc((dec - 1)/ 26, islower) .. abc
  end
end

local function abc2dec(abc)
  local cba = string.lower(abc)
  local a = 'a'
  local abc1 = string.sub(cba, 1, 1)
  local dec = abc1:byte() - a:byte() + 1
  if string.len(cba) == 1 then
    return dec
  else
    return math.floor(26 ^ string.len(abc) - 1) * dec + abc2dec(string.sub(abc, 1, string.len(abc) - 1))
  end
end

local function next_abc_bullet(bullet)
  local islower = bullet.bullet == string.lower(bullet.bullet)
  return dec2abc(abc2dec(bullet.bullet) + 1, islower)
end

local function next_num_bullet(bullet)
  return bullet.bullet + 1
end

local function next_chk_bullet(bullet)
  return bullet.bullet[0] .. ' [' .. string.sub(vim.api.nvim_get_var("bullets_checkbox_markers"), 1, 1) .. ']'
end

local function next_bullet_str(bullet)
  local bullet_type = bullet.bullet_type
  local next_bullet_marker = ''

  if bullet_type == 'rom' then
    next_bullet_marker = next_rom_bullet(bullet)
  elseif bullet_type == 'abc' then
    next_bullet_marker = next_abc_bullet(bullet)
  elseif bullet_type == 'num' then
    next_bullet_marker = next_num_bullet(bullet)
  elseif bullet_type == 'chk' then
    next_bullet_marker = next_chk_bullet(bullet)
  else
    next_bullet_marker = bullet.bullet
  end
  return bullet.leading_space .. next_bullet_marker .. bullet.closure  .. ' '
end

local function pad_to_length(str, len)
  if vim.api.nvim_get_var("bullets_pad_right") == 0 then
    return str
  end
  len = len - len(str)
  str = str
  if (len <= 0) then
    return str
  end
  while len > 0 do
    str = str .. ' '
    len = len - 1
  end
  return str
end

local function line_ends_in_colon(lnum)
  local line = vim.fn.getline(lnum)
  return string.sub(line, string.len(line)-1,string.len(line)) == ":"
end

local function change_bullet_level(direction)
  local lnum = vim.fn.line('.')
  local curr_line = parse_bullet(lnum, vim.fn.getline(lnum))

  if direction == 1 then
    if next(curr_line) ~= nil and vim.fn.indent(lnum) == 0 then
      -- Promoting a bullet at the highest level will delete the bullet
      vim.fn.setline(lnum, curr_line[0].text_after_bullet)
      vim.cmd("execute 'normal! $'")
      return
    else
      vim.cmd("execute 'normal! <<$'")
    end
  else
    vim.cmd("execute 'normal! >>$'")
  end

  if next(curr_line) == nil then
    -- If the current line is not a bullet then don't do anything else.
    return
  end

  local curr_indent = vim.fn.indent(lnum)
  local curr_bullet= closest_bullet_types(lnum, curr_indent)
  curr_bullet = resolve_bullet_type(curr_bullet)

  curr_line = curr_bullet.starting_at_line_num
  local closest_bullet = closest_bullet_types(curr_line - vim.api.nvim_get_var("bullets_line_spacing"), curr_indent)
  closest_bullet = resolve_bullet_type(closest_bullet)

  if next(closest_bullet) == nil then
    -- If there is no parent/sibling bullet then this bullet shouldn't change.
    return
  end

  local islower = closest_bullet.bullet == string.lower(closest_bullet.bullet)
  local closest_indent = vim.fn.indent(closest_bullet.starting_at_line_num)

  local closest_type = closest_bullet.bullet_type
  if islower then
    closest_type = string.upper(closest_bullet.bullet_type)
  end
  if closest_bullet.bullet_type == 'std' then
    -- Append the bullet marker to the type, e.g., 'std*'
   closest_type = closest_type .. closest_bullet.bullet
  end

  local bullets_outline_levels = vim.api.nvim_get_var("bullets_outline_levels")
  local closest_index = -1
  for _, v in ipairs(bullets_outline_levels) do
    if closest_type == v then
      closest_index = v
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

    local next_bullet = next_bullet_str(closest_bullet)
    bullet_str = pad_to_length(next_bullet, closest_bullet.bullet_length) .. curr_bullet.text_after_bullet

  elseif closest_index + 1 >= #bullets_outline_levels and curr_indent > closest_indent then
    -- The closest bullet is a parent and its type is the last one defined in
    -- g:bullets_outline_levels so keep the existing bullet.
    -- TODO: Might make an option for whether the bullet should stay or be
    -- deleted when demoting past the end of the defined bullet types.
    return
  elseif closest_index + 1 < #bullets_outline_levels or curr_indent < closest_indent then
    -- The current bullet is a child of the closest bullet so figure out
    -- what bullet type it should have and set its marker to the first
    -- character of that type.

    local next_type = bullets_outline_levels[closest_index + 1]
    local next_islower = next_type == string.lower(next_type)
    local trailing_space = ' '
    curr_bullet.closure = closest_bullet.closure

    -- set the bullet marker to the first character of the new type
    local next_num
    if next_type == 'rom' then
      next_num = num_to_rom(1, next_islower)
    elseif next_type == 'abc' then
      next_num = dec2abc(1, next_islower)
    elseif next_type ==# 'num' then
      next_num = '1'
    else
      -- standard bullet; the last character of next_type contains the bullet
      -- symbol to use
      next_num = string.sub(next_type, string.len(next_type) - 1, string.len(next_type))
      curr_bullet.closure = ''
    end

    bullet_str = curr_bullet.leading_space .. next_num .. curr_bullet.closure .. trailing_space .. curr_bullet.text_after_bullet

  else
    -- We're outside of the defined outline levels
    bullet_str = curr_bullet.leading_space .. curr_bullet.text_after_bullet
  end

  -- Apply the new bullet
  vim.fn.setline(lnum, bullet_str)

  vim.cmd("execute 'normal! $'")
end

local function visual_change_bullet_level(direction)
  -- Changes the bullet level for each of the selected lines
  local start_val = { unpack(vim.fn.getpos("'<"), 2, 2) }
  local end_val = { unpack(vim.fn.getpos("'>"), 2, 2) }
  local selected_lines = {start_val[1]}
  local j = 1
  for i = start_val[1], end_val[1] do
    selected_lines[j] = i
    j = j + 1
  end
  for lnum in selected_lines do
    -- Iterate the cursor position over each line and then call
    -- s:change_bullet_level for that cursor position.
    vim.fn.setpos('.', {0, lnum, 1, 0})
    change_bullet_level(direction)
  end
  if vim.api.nvim_get_var("bullets_renumber_on_change") then
    -- Pass the current visual selection so that it gets reset after
    -- renumbering the list.
    renumber_whole_list(start_val, end_val)
  end
end

local function first_bullet_line(line_num, min_indent)
  -- returns the line number of the first bullet in the list containing the
  -- given line number, up to the first blank line
  -- returns -1 if lnum is not in a list
  -- Optional argument: only consider bullets at or above this indentation
  local indent = min_indent or 0
  local lnum = line_num
  local first_line = -1
  local curr_indent = vim.fn.indent(lnum)
  local bullet_kinds = closest_bullet_types(lnum, curr_indent)
  local blank_lines = 0
  local list_start = false
  if indent < 0 then
    -- sanity check
    return -1
  end

  while lnum >= 1 and not list_start and curr_indent >= indent do
    if next(bullet_kinds) ~= nil then
      first_line = lnum
      blank_lines = 0
    else
      blank_lines = blank_lines + 1
      list_start = blank_lines >= vim.api.nvim_get_var("bullets_line_spacing")
    end
    lnum = lnum - 1
    curr_indent = vim.fn.indent(lnum)
    bullet_kinds = closest_bullet_types(lnum, curr_indent)
  end
  return first_line
end

local function last_bullet_line(line_num, min_indent)
  -- returns the line number of the last bullet in the list containing the
  -- given line number, down to the end of the list
  -- returns -1 if lnum is not in a list
  -- Optional argument: only consider bullets at or above this indentation
  local indent = min_indent or 0
  local lnum = line_num
  local buf_end = vim.fn.line('$')
  local last_line = -1
  local curr_indent = vim.fn.indent(lnum)
  local bullet_kinds = closest_bullet_types(lnum, curr_indent)
  local blank_lines = 0
  local list_end = false

  if min_indent < 0 then
    -- sanity check
    return -1
  end

  while lnum <= buf_end and not list_end and curr_indent >= min_indent do
    if next(bullet_kinds) ~= nil then
      last_line = lnum
      blank_lines = 0
    else
      blank_lines = blank_lines + 1
      list_end = blank_lines >= vim.api.nvim_get_var("bullets_line_spacing")
    end
    lnum = lnum + 1
    curr_indent = indent(lnum)
    bullet_kinds = closest_bullet_types(lnum, curr_indent)
  end
  return last_line
end

local function get_visual_selection_lines()
  local pos1 = vim.fn.getpos("'<")
  local pos2 = vim.fn.getpos("'>")
  local lines = vim.fn.getline(pos1[2], pos2[2])
  local inclusive = 2
  if vim.api.nvim_get_option("selection") == "inclusive" then
    inclusive = 1
  end
  lines[#lines] = string.sub(lines[#lines], 1, pos2[3] - inclusive)
  lines[1] = string.sub(lines[1], pos1[2] - 1)
  local index = pos1[2]
  local lines_with_index = {}
  for _, line in ipairs(lines) do
    local tmp = {}
    tmp['text'] = line
    tmp['nr'] = index
    table.insert(lines_with_index, tmp)
    index = index + 1
  end
  return lines_with_index
end

-- Checkboxes --------------------------------------------- {{{
local function find_checkbox_position(lnum)
  local line_text = vim.fn.getline(lnum)
  return vim.fn.matchend(line_text, "\\v\\s*(\\*|-) \\[")
end

local function select_checkbox(inner)
  local lnum = vim.fn.line('.')
  local checkbox_col = find_checkbox_position(lnum)

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

local function set_checkbox(lnum, marker)
  local curline = vim.fn.getline(lnum)
  local initpos = vim.fn.getpos('.')
  local pos = find_checkbox_position(lnum)
  if pos >= 0 then
    local front = string.sub(curline, 1, pos - 1)
    local back = string.sub(curline, pos + 1)
    vim.fn.setline(lnum, front, marker, back)
    vim.fn.setpos('.', initpos)
  end
end

local function toggle_checkbox(lnum)
  -- Toggles the checkbox on line a:lnum.
  -- Returns the resulting statu (1) checked, (0) unchecked, (-1) unchanged
  local indent = vim.fn.indent(lnum)
  local bullet = closest_bullet_types(lnum, indent)
  bullet = resolve_bullet_type(bullet)
  local checkbox_content = bullet.checkbox_marker
  if next(bullet) == nil or bullet['checkbox_marker'] == nil then
    return -1
  end

  local checkbox_markers = vim.api.nvim_get_var("bullets_checkbox_markers")
  -- get markers that aren't empty or fully checked
  local partial_markers = string.sub(checkbox_markers, 2, #checkbox_markers - 1)
  local marker
  if vim.api.nvim_get_var("bullets_checkbox_partials_toggle") > 0 and string.find(partial_markers, checkbox_content) ~= nil then
    -- Partially complete
    marker = string.sub(checkbox_markers, 1, 1)
    if vim.api.nvim_get_var("bullets_checkbox_partials_toggle") > 0 then
      marker = string.sub(checkbox_markers,#checkbox_markers, 1)
    end
  elseif checkbox_content == string.sub(checkbox_markers, 1, 1) then
    marker = string.sub(checkbox_markers,#checkbox_markers, 1)
  elseif string.find(checkbox_content, 'x') ~= nil or string.find(checkbox_content, 'X') ~= nil or string.find(checkbox_content, string.sub(checkbox_markers, #checkbox_markers, 1)) ~= nil then
    marker = string.sub(checkbox_markers, 1, 1)
  else
    return -1
  end

  set_checkbox(lnum, marker)
  return marker == string.sub(checkbox_markers, #checkbox_markers, 1)
end

local function get_sibling_line_numbers(lnum)
  -- returns a list with line numbers of the sibling bullets with the same
  -- indentation as a:indent, starting from the given line number, a:lnum
  local indent = vim.fn.indent(lnum)
  local first_sibling = first_bullet_line(lnum, indent)
  local last_sibling = last_bullet_line(lnum, indent)
  local siblings = {}
  for l = first_sibling, last_sibling do
    if vim.fn.indent(l) == indent then
      local bullet = parse_bullet(l, vim.fn.getline(l))
      if next(bullet) ~= nil then
        table.insert(siblings, l)
      end
    end
  end
  return siblings
end

local function get_children_line_numbers(line_num)
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
  local bullet_kinds = closest_bullet_types(lnum, curr_indent)
  local child_lnum = 0
  local blank_lines = 0

  while lnum <= buf_end and child_lnum == 0 do
    if next(bullet_kinds) ~= nil and curr_indent > indent then
      child_lnum = lnum
    else
      blank_lines = blank_lines + 1
      if blank_lines >= vim.api.nvim_get_var("bullets_line_spacing") then
        child_lnum = -1
      else
        child_lnum = 0
      end
    end
    lnum = lnum + 1
    curr_indent = indent(lnum)
    bullet_kinds = closest_bullet_types(lnum, curr_indent)
  end

  if child_lnum > 0 then
    return get_sibling_line_numbers(child_lnum)
  else
    return {}
  end
end

local function sibling_checkbox_status(lnum)
  -- Returns the marker corresponding to the proportion of siblings that are
  -- completed.
  local siblings = get_sibling_line_numbers(lnum)
  local num_siblings = #siblings
  local checked = 0
  local checkbox_markers = vim.api.nvim_get_var("bullets_checkbox_markers")
  for _, l in ipairs(siblings) do
    local indent = vim.fn.indent(l)
    local bullet = closest_bullet_types(l, indent)
    bullet = resolve_bullet_type(bullet)
    if next(bullet) ~= nil and bullet.checkbox_marker ~= "" then
      if string.find(bullet.checkbox_marker, string.sub(checkbox_markers,string.len(checkbox_markers), 1)) ~= nil then
        -- Checked
        checked = checked + 1
      end
    end
  end
  local divisions = string.len(checkbox_markers) - 1
  local completion = math.ceil(divisions * checked / num_siblings)
  return string.sub(checkbox_markers, completion, 1)
end

local function get_parent(lnum)
  -- returns the parent bullet of the given line number, lnum, with indentation
  -- at or below the given indent.
  -- if there is no parent, returns an empty dictionary
  local indent = vim.fn.indent(lnum)
  if indent < 0 then
    return {}
  end
  local parent = closest_bullet_types(lnum, indent - 1)
  parent = resolve_bullet_type(parent)
  return parent
end

local set_parent_checkboxes
set_parent_checkboxes = function(lnum, marker)
  -- set the parent checkbox of line a:lnum, as well as its parents, based on
  -- the marker passed in a:marker
  if not vim.api.nvim_get_var("bullets_nested_checkboxes") then
    return
  end

  local parent = get_parent(lnum)
  if next(parent) ~= nil and parent.bullet_type == 'chk' then
    -- Check for siblings' status
    local pnum = parent.starting_at_line_num
    set_checkbox(pnum, marker)
    set_parent_checkboxes(pnum, sibling_checkbox_status(pnum))
  end
end

local function set_child_checkboxes(lnum, checked)
  -- set the children checkboxes of line a:lnum based on the value of a:checked
  -- 0: unchecked, 1: checked, other: do nothing
  if not vim.api.nvim_get_var("bullets_nested_checkboxes") or not (checked == 0 or checked == 1) then
    return
  end

  local children = get_children_line_numbers(lnum)
  if next(children) ~= nil then
    local checkbox_markers = vim.api.nvim_get_var("bullets_checkbox_markers")
    for child in children do
      local marker
      if checked then
        marker = string.sub(checkbox_markers, string.len(checkbox_markers), 1)
      else
        marker = string.sub(checkbox_markers, 1, 1)
      end
      set_checkbox(child, marker)
      set_child_checkboxes(child, checked)
    end
  end
end

local function toggle_checkboxes_nested()
  -- toggle checkbox on the current line, as well as its parents and children
  local lnum = vim.fn.line('.')
  local indent = vim.fn.indent(lnum)
  local bullet = closest_bullet_types(lnum, indent)
  bullet = resolve_bullet_type(bullet)

  -- Is this a checkbox? Do nothing if it's not, otherwise toggle the checkbox
  if next(bullet) == nil or bullet.bullet_type ~= 'chk' then
    return
  end

  local checked = toggle_checkbox(lnum)

  if vim.api.nvim_get_var("bullets_nested_checkboxes") then
    -- Toggle children and parents
    local completion_marker = sibling_checkbox_status(lnum)
    set_parent_checkboxes(lnum, completion_marker)

    -- Toggle children
    if checked >= 0 then
      set_child_checkboxes(lnum, checked)
    end
  end
end

-- Checkboxes --------------------------------------------- }}}

-- Renumbering --------------------------------------------- {{{
local function get_level(bullet)
  if next(bullet) == nil or bullet.bullet_type ~= 'std' then
    return 0
  else
    return string.len(bullet.bullet)
  end
end

local function renumber_selection()
  local selection_lines = get_visual_selection_lines()
  local prev_indent = -1
  local levels = {}  -- stores all the info about the current outline/list

  for _, line in ipairs(selection_lines) do
    local indent = vim.fn.indent(line.nr)
    local bullet = closest_bullet_types(line.nr, indent)
    bullet = resolve_bullet_type(bullet)
    local curr_level = get_level(bullet)
    if curr_level > 1 then
      -- then it's an AsciiDoc list and shouldn't be renumbered
      break
    end

    if next(bullet) ~= nil and bullet.starting_at_line_num == line.nr then
      -- skip wrapped lines and lines that aren't bullets
      if (indent > prev_indent or levels[indent] == nil) and bullet.bullet_type ~= 'chk' and bullet.bullet_type ~= 'std' then
        if levels[indent] == nil then
          levels[indent].index = 1
        end

        -- use the first bullet at this level to define the bullet type for
        -- subsequent bullets at the same level. Needed to normalize bullet
        -- types when there are multiple types of bullets at the same level.
        levels[indent].islower = bullet.bullet == string.lower(bullet.bullet)
        levels[indent].type = bullet.bullet_type
        levels[indent].bullet = bullet.bullet  -- for standard bullets
        levels[indent].closure = bullet.closure  -- normalize closures
        levels[indent].trailing_space = bullet.trailing_space
      else
        if bullet.bullet_type ~= 'chk' and bullet.bullet_type ~= 'std' then
          levels[indent].index = levels[indent].index + 1
        end

        if indent < prev_indent then
          -- Reset the numbering on all all child items. Needed to avoid continuing
          -- the numbering from earlier portions of the list with the same bullet
          -- type in some edge cases.
          for key, _ in ipairs(levels) do
            if key > indent then
              levels[key] = nil
            end
          end
        end
      end

      prev_indent = indent

      local bullet_num = levels[indent].index
      local new_bullet = ""
      if bullet.bullet_type ~= 'chk' and bullet.bullet_type ~= 'std' then
        if levels[indent].type == 'rom' then
          bullet_num = num_to_rom(levels[indent].index, levels[indent].islower)
        elseif levels[indent].type == 'abc' then
          bullet_num = dec2abc(levels[indent].index, levels[indent].islower)
        end

        new_bullet = bullet_num .. levels[indent].closure .. levels[indent].trailing_space
        if levels[indent].index > 1 then
          new_bullet = pad_to_length(new_bullet, levels[indent].pad_len)
        end
        levels[indent].pad_len = string.len(new_bullet)
        local renumbered_line = bullet.leading_space .. new_bullet .. bullet.text_after_bullet
        vim.fn.setline(line.nr, renumbered_line)
      elseif bullet.bullet_type == 'chk' then
        -- Reset the checkbox marker if it already exists, or blank otherwise
        local marker = ' '
        if bullet.checkbox_marker ~= nil then
          marker = bullet.checkbox_marker
        end
        set_checkbox(line.nr, marker)
      end
    end
  end
end

local function renumber_whole_list(start_pos, end_pos)
  -- Renumbers the whole list containing the cursor.
  -- Does not renumber across blank lines.
  -- Takes 2 optional arguments containing starting and ending cursor positions
  -- so that we can reset the existing visual selection after renumbering.
  local spos = start_pos or {}
  local epos = end_pos or {}
  local first_line = first_bullet_line(vim.fn.line('.'))
  local last_line = last_bullet_line(vim.fn.line('.'))
  if first_line > 0 and last_line > 0 then
    -- Create a visual selection around the current list so that we can call
    -- renumber_selection() to do the renumbering.
    vim.fn.setpos("'<", {0, first_line, 1, 0})
    vim.fn.setpos("'>", {0, last_line, 1, 0})
    renumber_selection()
    if next(spos) ~= nil and next(epos) ~= nil then
      -- Reset the starting visual selection
      vim.fn.setpos("'<", {0, spos[1], spos[2], 0})
      vim.fn.setpos("'>", {0, epos[1], epos[2], 0})
      vim.cmd("execute 'normal! gv'")
    end
  end
end

local function change_bullet_level_and_renumber(direction)
  -- Calls change_bullet_level and then renumber_whole_list if required
  change_bullet_level(direction)
  if vim.api.nvim_get_var("bullets_renumber_on_change") then
    renumber_whole_list()
  end
end

local function insert_new_bullet()
  local curr_line_num = vim.fn.line('.')
  local next_line_num = curr_line_num + vim.api.nvim_get_var("bullets_line_spacing")
  local curr_indent = vim.fn.indent(curr_line_num)
  local bullet_types = closest_bullet_types(curr_line_num, curr_indent)
  local bullet = resolve_bullet_type(bullet_types)
  -- need to find which line starts the previous bullet started at and start
  -- searching up from there
  local send_return = 1
  local normal_mode = vim.fn.mode() == 'n'
  local indent_next = line_ends_in_colon(curr_line_num) and vim.api.nvim_get_var("bullets_auto_indent_after_colon")
  local next_bullet_list = {}

  -- check if current line is a bullet and we are at the end of the line (for
  -- insert mode only)
  local is_at_eol = string.len(vim.fn.getline('.')) + 1 == vim.fn.col('.')
  if next(bullet) ~= nil and (normal_mode or is_at_eol) then
    -- was any text entered after the bullet?
    if bullet.text_after_bullet == '' then
      -- We don't want to create a new bullet if the previous one was not used,
      -- instead we want to delete the empty bullet - like word processors do
      if vim.api.nvim_get_var("bullets_delete_last_bullet_if_empty") then
        vim.cmd("call setline(" .. curr_line_num ..", '')")
        send_return = 0
      end
    elseif not (bullet.bullet_type == 'abc' and abc2dec(bullet.bullet) + 1 > abc_max) then
      local next_bullet = next_bullet_str(bullet)
      if bullet.bullet_type == 'chk' then
        next_bullet_list = {next_bullet}
      else
        next_bullet_list = {pad_to_length(next_bullet, bullet.bullet_length)}
      end

      -- prepend blank lines if desired
      if vim.api.nvim_get_var("bullets_line_spacing") > 1 then
        for i = 1,vim.api.nvim_get_var("bullets_line_spacing") do
          table.insert(next_bullet_list, i, "")
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
        change_bullet_level_and_renumber(-1)
        -- reset cursor position after indenting
        col = string.len(vim.fn.getline(next_line_num)) + 1
        vim.fn.setpos('.', {0, next_line_num, col})
      elseif vim.api.nvim_get_var("bullets_renumber_on_change") then
        renumber_whole_list()
      end

      send_return = 0
    end
  end

  if send_return or normal_mode then
    -- start a new line
    if normal_mode then
      vim.cmd("startinsert!")
    end

    local keys = ""
    if send_return then
      keys = "\\<CR>"
    end
    vim.fn.feedkeys(keys, 'n')
  end

  -- need to return a string since we are in insert mode calling with <C-R>=
  return ''
end

return {
  insert_new_bullet = insert_new_bullet,
  select_checkbox = select_checkbox,
  toggle_checkboxes_nested = toggle_checkboxes_nested,
  renumber_selection = renumber_selection,
  renumber_whole_list = renumber_whole_list,
  change_bullet_level_and_renumber = change_bullet_level_and_renumber,
  visual_change_bullet_level = visual_change_bullet_level,
  select_bullet_text = select_bullet_text
}
