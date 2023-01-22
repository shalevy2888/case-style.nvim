-- case_style = case_style or require('case-style')
local config = require('case-style.config')

local M = {}

M.input_params = {
    prompt = '> ',
    on_confirm = nil,
    on_cancel = nil,
    case_sensative = true,
    whole_word = true,
    case_style = 'snake',
    case_style_selected_index = 1,
    scope = config.get_mod_config('scope'),
    search_bufnr = nil,
    style_bufnr = nil,
    list_option = nil,
    text_to_replace = nil,
}

M.case_style = nil

local function _close_all_windows(winid_table)
    for _, winid in ipairs(winid_table) do
        pcall(vim.api.nvim_win_close, winid, true)
    end
end

local function _get_visual_selection()
    -- Yank current visual selection into the 'v' register
    -- Note that this makes no effort to preserve this register
    vim.cmd('noau normal! "vy"')
    return vim.fn.getreg('v')
end

local function _change_buffer_message(bufnr, messege)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    -- add messege
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, messege)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

local function _format_search_params()
    return string.format('<C-c>%scase-sensative <C-w>%swhole-word', M.input_params.case_sensative == true and '*' or ' '
        ,
        M.input_params.whole_word == true and '*' or ' ')
end

local function _format_scope_params()
    return string.format('<C-s>%sSingle <C-b>%sBuf <C-p>%sProject', M.input_params.scope == 'single' and '*' or ' ',
        M.input_params.scope == 'buf' and '*' or ' ', M.input_params.scope == 'project' and '*' or ' ')
end

local _case_styles = {
    'snake',
    'camel',
    'pascal',
    'kebab',
    'CAPS',
}

local function _format_case_style_params()
    local ret_table = {}
    for i = 1, table.getn(M.input_params.list_option) do
        table.insert(ret_table,
            string.format('%s%s', M.input_params.case_style == _case_styles[i] and '*' or ' ',
                M.input_params.list_option[i]))
    end
    -- return {
    --     string.format('<C-q>%ssnake', M.input_params.case_style == 'snake' and '*' or ' '),
    --     string.format('<C-w>%scamel', M.input_params.case_style == 'camel' and '*' or ' '),
    --     string.format('<C-e>%spascal', M.input_params.case_style == 'pascal' and '*' or ' '),
    --     string.format('<C-r>%skebab', M.input_params.case_style == 'kebab' and '*' or ' '),
    --     string.format('<C-t>%sCAPS', M.input_params.case_style == 'CAPS' and '*' or ' '),
    -- }
    return ret_table
end

function case_style_change_style(dir)
    M.input_params.case_style_selected_index = M.input_params.case_style_selected_index + dir
    if M.input_params.case_style_selected_index < 1 then
        M.input_params.case_style_selected_index = 1
    elseif M.input_params.case_style_selected_index > table.getn(M.input_params.list_option) then
        M.input_params.case_style_selected_index = table.getn(M.input_params.list_option)
    end
    M.input_params.case_style = _case_styles[M.input_params.case_style_selected_index]
    local key = vim.api.nvim_replace_termcodes('<BS>', true, false, true)
    local line_under_cursor = vim.fn.getline(vim.fn.line('.'))
    local prompt_len = string.len(M.input_params.prompt)
    local text = string.sub(line_under_cursor, prompt_len + 1)
    local text_length = string.len(text)
    for i = 1, text_length, 1 do
        vim.api.nvim_feedkeys(key, 'n', false)
    end
    vim.api.nvim_feedkeys(M.input_params.list_option[M.input_params.case_style_selected_index], 'n', false)

    _change_buffer_message(M.input_params.style_bufnr, _format_case_style_params())
end

function case_style_toggle_search_case_sensative()
    M.input_params.case_sensative = not M.input_params.case_sensative
    _change_buffer_message(M.input_params.search_bufnr, { _format_search_params() })
end

function case_style_toggle_search_whole_word()
    M.input_params.whole_word = not M.input_params.whole_word
    _change_buffer_message(M.input_params.search_bufnr, { _format_search_params() })
end

function case_style_scope_single()
    M.input_params.scope = 'single'
    _change_buffer_message(M.input_params.scope_bufnr, { _format_scope_params() })
end

function case_style_scope_buf()
    M.input_params.scope = 'buf'
    _change_buffer_message(M.input_params.scope_bufnr, { _format_scope_params() })
end

function case_style_scope_project()
    M.input_params.scope = 'project'
    _change_buffer_message(M.input_params.scope_bufnr, { _format_scope_params() })
end

function case_style_confirm(winid_table)
    vim.cmd("stopinsert")
    -- print('confirm')
    local line_under_cursor = vim.fn.getline(vim.fn.line('.'))
    local prompt_len = string.len(M.input_params.prompt)
    local text = string.sub(line_under_cursor, prompt_len + 1)
    -- We have to wait briefly for the popup window to close (if present)
    vim.defer_fn(function()
        _close_all_windows(winid_table)
        vim.defer_fn(function()
            if M.input_params.on_confirm ~= nil then
                M.input_params.on_confirm(text)
            end
            if M.case_style ~= nil then
                M.case_style.change_case_with_options({ M.input_params.text_to_replace, text, M.input_params.scope })
            end
        end, 5)
    end, 5)
end

function case_style_cancel(winid_table)
    vim.cmd("stopinsert")
    print('cancel')
    -- We have to wait briefly for the popup window to close (if present)
    vim.defer_fn(function()
        _close_all_windows(winid_table)
        vim.defer_fn(function()
            if M.input_params.on_cancel ~= nil then
                M.input_params.on_cancel()
            end
        end, 5)
    end, 5)

end

local function _open_float_window(width, height, row_offset, type, messege)
    --local width = 30
    --local height = 1
    -- Create a scratch buffer
    local bufnr = vim.api.nvim_create_buf(false, true)

    -- We do not need swapfile for this buffer.
    vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
    -- And we would rather prefer that this buffer will be destroyed when hide.
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    -- It's not necessary but it is good practice to set custom filetype.
    -- This allows users to create their own autocommand or colorschemes on filetype.
    -- and prevent collisions with other plugins.
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'nvim-case-style')
    local prompt = M.input_params.prompt
    if type == 'prompt' then
        vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
        vim.api.nvim_buf_set_option(bufnr, 'buftype', 'prompt')
        vim.fn.prompt_setprompt(bufnr, prompt)
    elseif type == 'messege' then
        vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
        if messege ~= nil then
            -- add messege
            _change_buffer_message(bufnr, messege)
        end
    end
    -- get the current ui window for the col / row
    local ui = vim.api.nvim_list_uis()[1]

    local opts = { relative = 'editor',
        width = width,
        height = height,
        col = (ui.width / 2) - (width / 2),
        row = (ui.height / 2) + row_offset,
        anchor = 'nw',
        style = 'minimal',
        border = 'single',
        -- title = 'title',
        focusable = type == 'prompt' and true or false
    }
    local winnr = vim.api.nvim_open_win(bufnr, true, opts)

    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
        buffer = bufnr,
        callback = function()
            local new_text = vim.trim(vim.fn.getline('.'):sub(#prompt + 1, -1))
            -- log('text changed', new_text)
            if #new_text == 0 then -- or new_text == input_ctx.opts.default then
                return
            end
            --input_ctx.on_change(new_text)
        end,
    })
    -- For better UX we will turn off line wrap and turn on current line highlight.
    vim.api.nvim_win_set_option(winnr, 'wrap', false)
    vim.api.nvim_win_set_option(winnr, 'cursorline', true)

    -- change highlight color
    vim.api.nvim_win_set_option(winnr, 'winhl', 'Normal:ErrorFloat')
    -- vim.cmd(string.format('normal i%s', 'placeholder'))
    if type == 'prompt' then
        vim.cmd('startinsert!')
        if messege ~= nil then
            vim.api.nvim_feedkeys(messege[1], 'n', false)
        end
    end
    return winnr, bufnr
end

M.open_input_and_options_windows = function(text_to_replace, list_options)
    local offset = -15
    local width = 40
    M.input_params.text_to_replace = text_to_replace
    -- reset the options
    M.input_params.scope = config.get_mod_config('scope')
    M.input_params.case_style = 'snake'
    M.input_params.case_style_selected_index = 1

    -- check in what mode we are in:
    local cur_mode = vim.fn.mode()
    local title_winnr, title_bufnr = _open_float_window(width, 1, offset, 'messege', { 'replace: ' .. text_to_replace })
    offset = offset + 2
    local prompt_winnr, prompt_bufnr = _open_float_window(width, 1, offset, 'prompt', { text_to_replace })
    offset = offset + 2
    local list_winnr, list_bufnr
    local search_winnr, search_bufnr
    if cur_mode == 'n' then
        M.input_params.list_option = list_options
        list_winnr, list_bufnr = _open_float_window(width, 5, offset, 'messege',
            _format_case_style_params())
        M.input_params.style_bufnr = list_bufnr
        case_style_change_style(0) -- make sure to update the prompt
    elseif cur_mode == 'v' then
        search_winnr, search_bufnr = _open_float_window(width, 1, offset, 'messege',
            { _format_search_params(), })
        M.input_params.search_bufnr = search_bufnr
    end
    offset = offset + 6
    local scope_winnr, scope_bufnr = _open_float_window(width, 1, offset, 'messege',
        { _format_scope_params(), })
    M.input_params.scope_bufnr = scope_bufnr

    local bufnr = { title_bufnr, prompt_bufnr, cur_mode == 'n' and list_bufnr or search_bufnr, scope_bufnr }
    local winnr = { title_winnr, prompt_winnr, cur_mode == 'n' and list_winnr or search_winnr, scope_winnr }
    -- set local key maps to close the window:
    -- local closingKeys = { '<Esc>', '<CR>', '<Leader>' }
    -- for _, closingKey in pairs(closingKeys) do
    --     for _, buf in pairs(bufnr) do
    --         vim.api.nvim_buf_set_keymap(buf, 'n', closingKey, ':bd!<CR>',
    --             { silent = true, nowait = true, noremap = true })
    --     end
    -- end

    -- set <CR> as confirm
    local lua_cmd = string.format('<cmd> lua case_style_confirm({%d, %d, %d, %d})<CR>', title_winnr, prompt_winnr,
        cur_mode == 'n' and list_winnr or search_winnr, scope_winnr)
    vim.api.nvim_buf_set_keymap(prompt_bufnr, 'i', '<CR>', lua_cmd, { silent = true, nowait = true, noremap = false })
    -- set <ESC> as cancel
    lua_cmd = string.format('<cmd> lua case_style_cancel({%d, %d, %d, %d})<cr>', title_winnr, prompt_winnr,
        cur_mode == 'n' and list_winnr or search_winnr, scope_winnr)
    vim.api.nvim_buf_set_keymap(prompt_bufnr, 'i', '<ESC>', lua_cmd, { silent = true, nowait = true, noremap = false })

    vim.api.nvim_buf_set_keymap(prompt_bufnr, 'i', '<C-c>', '<cmd> lua case_style_toggle_search_case_sensative()<CR>',
        { silent = true, nowait = true, noremap = false })
    vim.api.nvim_buf_set_keymap(prompt_bufnr, 'i', '<C-a>', '<cmd> lua case_style_toggle_search_whole_word()<CR>',
        { silent = true, nowait = true, noremap = false })
    vim.api.nvim_buf_set_keymap(prompt_bufnr, 'i', '<C-s>', '<cmd> lua case_style_scope_single()<CR>',
        { silent = true, nowait = true, noremap = false })
    vim.api.nvim_buf_set_keymap(prompt_bufnr, 'i', '<C-b>', '<cmd> lua case_style_scope_buf()<CR>',
        { silent = true, nowait = true, noremap = false })
    vim.api.nvim_buf_set_keymap(prompt_bufnr, 'i', '<C-p>', '<cmd> lua case_style_scope_project()<CR>',
        { silent = true, nowait = true, noremap = false })
    vim.api.nvim_buf_set_keymap(prompt_bufnr, 'i', '<C-k>', "<cmd> lua case_style_change_style(-1)<CR>",
        { silent = true, nowait = true, noremap = false })
    vim.api.nvim_buf_set_keymap(prompt_bufnr, 'i', '<C-j>', "<cmd> lua case_style_change_style(1)<CR>",
        { silent = true, nowait = true, noremap = false })
    vim.api.nvim_buf_set_keymap(prompt_bufnr, 'i', '<Up>', "<cmd> lua case_style_change_style(-1)<CR>",
        { silent = true, nowait = true, noremap = false })
    vim.api.nvim_buf_set_keymap(prompt_bufnr, 'i', '<Down>', "<cmd> lua case_style_change_style(1)<CR>",
        { silent = true, nowait = true, noremap = false })
    vim.api.nvim_set_current_win(prompt_winnr)
end

--local pwn, pwb = _open_float_window(30, 1, -15, 'prompt')
--_open_float_window(30, 4, 0, 'messege', { '1. line', '2. second', '3. third', })
--vim.api.nvim_set_current_win(pwn)
--
-- _open_input_and_options_windows({ 'this_is_a_variable', 'ThisIsAVariable', 'thisIsAVariable', 'this-is-a-variable',
--    'THIS_IS_A_VARIABLE' })A

return M
