# Bullets.nvim

A lua port of [bullets.vim](https://github.com/dkarter/bullets.vim)

## Setup

* Include the plugin using your plugin manager of choice.
* config is a table containing your chosen options (see the code for available options; no helpfile provided at this time).
* Include in your init.lua ```require('Bullets').setup({ config })``` **or** for Lazy:
```lua
{
  'kaymmm/bullets.nvim',
  opts = {
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
}
```

