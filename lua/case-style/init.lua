-- References used to create this plugin:
-- https://github.com/David-Kunz/treesitter-unit/blob/main/lua/treesitter-unit/init.lua
-- https://github.com/xiyaowong/nvim-cursorword/blob/master/plugin/nvim-cursorword.lua
-- https://gist.github.com/tjdevries/69771e9ac4605a9df893977055e21377
-- https://jacobsimpson.github.io/nvim-lua-manual/docs/buffers-and-windows/

-- print('case-style loaded!')

local config = require('case-style.config')

local M = {}

M.setup = function(opts)
    -- P(opts)
    config.update(opts)
end

local function _matchstr(...)
  local ok, ret = pcall(vim.fn.matchstr, ...)
  return ok and ret or ""
end

local function _replace_text(start_row, start_col, end_row, end_col, new_text)
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_text(bufnr, start_row - 1, start_col - 1, end_row - 1, end_col, { new_text })
end

local function _word_under_cusror()
  -- Get row and column
  local row, column
  if table.unpack == nil then
    row, column = unpack(vim.api.nvim_win_get_cursor(0))
  else
    row, column = table.unpack(vim.api.nvim_win_get_cursor(0))
  end
  -- local row, column = table.unpack(vim.api.nvim_win_get_cursor(0))
  -- get the full line under cursor
  local line = vim.api.nvim_get_current_line()
  -- get the left side of the word
  local left = _matchstr(line:sub(1, column + 1), [[\k*$]])
  -- get the right side
  local right = _matchstr(line:sub(column + 1), [[^\k*]]):sub(2)

  local cursorword = left .. right
  return cursorword, row, column + 2 - string.len(left), row, column + string.len(right) + 1
end

-- Find the first alphanumeric characters, assume what comes before is leading characters such as '_'
local function _leading_variable(variable_name)
  local start_of_word = string.find(variable_name, "%w")
  if start_of_word == 1 then
    return nil, variable_name
  else
    return string.sub(variable_name, 1, start_of_word - 1), string.sub(variable_name, start_of_word)
  end
end

-- _nword - finds the next word inside the variable name. Returns the word,
-- pos (could be nil), and should force CAP be used on this word
local function _nword(partial_var_name, begin)
  if begin == nil then
    begin = 0
  end
  local next_word = string.find(partial_var_name, "[%u_-]")
  local var_len = string.len(partial_var_name)
  if next_word == 1 and var_len > 1 then
    -- the begining of this word started with an upper case or '-' or '_'
    local first_char = string.sub(partial_var_name, 1, 1)
    if first_char == '_' or first_char == '-' then
      -- print('found _ or - in the begining')
      return _nword(string.sub(partial_var_name, 2), begin + 1)
    else
      -- This can be a begining of a word with Capital + lower, or it can be the
      -- begining of a word that is all capital. In the later case we will have another
      -- capital letter right next to it and we would consider a 'word' until the next lower
      -- minun 1 (assuming the next word afterwards also starts with capital). If this is the
      -- end of the variable than we don't minus 1.
      local next_upper = string.find(partial_var_name, '[%u]', 2)
      if next_upper == 2 then
        -- we have two capital letters one after the other:
        -- find the next lower:
        local next_lower = string.find(partial_var_name, '[%l]', 3)
        if next_lower == nil then
          -- the rest of the characters are all capital
          return string.lower(partial_var_name), nil, true -- True - force upper case
        else
          -- we still have more words to parse
          return string.lower(string.sub(partial_var_name, 1, next_lower - 2)), next_lower - 1 + begin, true -- True - force upper case
        end
      else
        partial_var_name = string.lower(first_char) .. string.sub(partial_var_name, 2)
        -- print('partial_var_name after lower of first letter: ', partial_var_name)
        return _nword(partial_var_name, begin)
      end
    end
  elseif next_word == nil then -- reached the end of the variable
    return string.sub(partial_var_name, 1), nil, false
  end
  return string.sub(partial_var_name, 1, next_word - 1), next_word + begin, false
end

local function _divide_word(variable_name)
  local word_array = {}
  local leading_chars
  leading_chars, variable_name = _leading_variable(variable_name)
  -- print(leading_chars, variable_name)
  word_array['leader'] = leading_chars
  word_array['words'] = {}
  local ww, next, preserve_case = _nword(variable_name)
  local loops = 0
  while next ~= nil do
    -- print('divide_word')
    -- print(ww, next)
    variable_name = string.sub(variable_name, next)
    table.insert(word_array['words'], { ww, preserve_case })
    ww, next, preserve_case = _nword(variable_name)
    loops = loops + 1
    if loops > 2000 then
      -- Make sure we don't run into infinite loop, for debug
      return word_array
    end
  end
  table.insert(word_array['words'], { ww, preserve_case })
  return word_array
end

local function _iterate_word_array(word_array, style_func)
  local ret_str = ""
  if word_array['leader'] ~= nil then
    ret_str = ret_str .. word_array['leader']
  end
  for k, v in ipairs(word_array['words']) do
    ret_str = ret_str .. style_func(k, v[1], v[2])
  end
  return ret_str

end

local function _lower_case(word_array, seperator)
  return _iterate_word_array(word_array, function(index, word, force)
    if force == true then
      -- force upper case
      word = string.upper(word)
    end
    if index > 1 then
      word = seperator .. word
    end
    return word
  end)
end

local function _snake_case(word_array)
  return _lower_case(word_array, '_')
end

local function _kebab_case(word_array)
  return _lower_case(word_array, '-')
end

local function _upper_case(word_array, start_from)
  return _iterate_word_array(word_array, function(index, word, force)
    -- print('camel_case: ', index, word, force)
    if index >= start_from then
      word = string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2)
    end
    if force == true then
      word = string.upper(word)
    end
    return word
  end)
end

local function _camel_case(word_array)
  return _upper_case(word_array, 2)
end

local function _pascal_case(word_array)
  return _upper_case(word_array, 1)
end

local function _caps_case(word_array)
  return _iterate_word_array(word_array, function(_, word, _)
    return string.upper(word)
  end)
end

local function _project_rename(new_name, open_qflist)
  local position_params = vim.lsp.util.make_position_params()

  position_params.newName = new_name

  vim.lsp.buf_request(0, "textDocument/rename", position_params, function(err, result, ...)
    -- You can uncomment this to see what the result looks like.
    if true then
      P(err)
      P(result)
    end
    if result == nil then
      return
    end
    vim.lsp.handlers["textDocument/rename"](err, result, ...)

    local entries = {}
    if not result.changes then
      -- print('no results')
      return
    end

    for uri, edits in pairs(result.changes) do
      local bufnr = vim.uri_to_bufnr(uri)
      print('bufnr: ', bufnr)
      for _, edit in ipairs(edits) do
        P(edit)
        local start_line = edit.range.start.line + 1
        local line = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, start_line, false)[1]

        table.insert(entries, {
          bufnr = bufnr,
          lnum = start_line,
          col = edit.range.start.character + 1,
          text = line,
        })
      end
    end
    if open_qflist == true then
      vim.fn.setqflist(entries, "r")
      vim.cmd('copen')
    end
  end)
end

local function _buffer_rename(old_name, new_name, open_qflist)
  local buf = vim.api.nvim_buf_get_lines(0, 0,
    vim.api.nvim_buf_line_count(0), false)
  local entries = {}
  for index, line in pairs(buf) do
    while true do
      local i, j = string.find(line, old_name)
      if i == nil then break end
      _replace_text(index, i, index, j, new_name)
      table.insert(entries, {
        bufnr = vim.api.nvim_get_current_buf(),
        lnum = index,
        col = i + 1,
        text = line,
      })
      -- We now need to reread the same line and search for old_name again
      line = vim.api.nvim_buf_get_lines(0, index - 1, index, false)[1]
    end
  end
  if next(entries) ~= nil then
    if open_qflist == true then
      vim.fn.setqflist(entries, "r")
      vim.cmd('copen')
    end
  end
end

M.change_case = function(style, s)
  local scope = config.get_mod_config('scope')

  if s ~= nil then
    scope = s
  end

  --local current_word = vim.call('expand','<cword>')
  local current_word, start_row, start_col, end_row, end_col = _word_under_cusror()
  -- print(current_word)
  if current_word == nil or current_word == '' then
    return
  end

  local style_word
  local divided_words = _divide_word(current_word)
  if style == 'snake' then
    style_word = _snake_case(divided_words)
  elseif style == 'camel' then
    style_word = _camel_case(divided_words)
  elseif style == 'pascal' then
    style_word = _pascal_case(divided_words)
  elseif style == 'kebab' then
    style_word = _kebab_case(divided_words)
  elseif style == 'caps' then
    style_word = _caps_case(divided_words)
  else
    print('requested style is not supported: ' .. style)
    return -- don't replace anything
  end
  -- local buf_num = vim.api.nvim_get_current_buf()
  -- local position_param = vim.lsp.util.make_position_params()
  -- P(position_param)
  --if scope == 'single' then
  --    vim.api.nvim_
  --
  if scope == 'single' then
    _replace_text(start_row, start_col, end_row, end_col, style_word)
  elseif scope == 'buf' then
    -- print('qflist value in config: ', config.get_mod_config('qflist'))
    _buffer_rename(current_word, style_word, config.get_mod_config('qflist'))
  elseif scope == 'project' then
    -- print('project rename')
    _project_rename(style_word, config.get_mod_config('qflist'))
  else
    print('requested scope is not supported: ' .. scope)
  end
end

vim.keymap.set("n", "<leader>cs", ":CaseStyle snake<CR>")
vim.keymap.set("n", "<leader>cc", ":CaseStyle camel<CR>")
vim.keymap.set("n", "<leader>ck", ":CaseStyle kebab<CR>")
vim.keymap.set("n", "<leader>cp", ":CaseStyle pascal<CR>")
vim.keymap.set("n", "<leader>cC", ":CaseStyle caps<CR>")


vim.api.nvim_create_user_command(
  'CaseStyle',
  function(opts)
    M.change_case(opts.args)
    --print(string.upper(opts.args))
  end,
  { nargs = 1 }
)

vim.api.nvim_create_user_command(
  'CaseStyleScope',
  function(opts)
    config.update({'scope', opts.args})
    --print(string.upper(opts.args))
  end,
  { nargs = 1 }
)

-- M.test_multiple_word()

-- _My_word2
-- SimpleTestOfWords
-- _open_float_window({'first line', 'second line'})

-- TestThisChange some words TestThisChange

return M
