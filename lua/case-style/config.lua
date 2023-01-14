local default_config = {
    -- scope:
  -- 'single' - replace just this one occurence,
  -- 'buf' - replace all in current buf (including in remarks - simple search and replace)
  -- 'project' - use lsp to rename across project
  scope = 'single',
  qflist = true, -- populate and open the qflist with the changes (only 'buf' and 'project' scope)
}

local M = vim.deepcopy(default_config)

M.update = function(opts)
  local newconf = vim.tbl_deep_extend("force", default_config, opts or {})

  for k, v in pairs(newconf) do
    M[k] = v
  end
end

M.get_mod_config = function(key)
    return M[key]
end

return M
