local source = require('cmp_nvim_lsp.source')

local M = {}

---Registered client and source mapping.
M.client_source_map = {}

---Setup cmp-nvim-lsp source.
M.setup = function()
  vim.cmd([[
    augroup cmp_nvim_lsp
      autocmd!
      autocmd InsertEnter * lua require'cmp_nvim_lsp'._on_insert_enter()
    augroup END
  ]])
end

local if_nil = function(val, default)
  if val == nil then return default end
  return val
end

-- Backported from vim.deprecate (0.9.0+)
local function deprecate(name, alternative, version, plugin, backtrace)
  local message = name .. ' is deprecated'
  plugin = plugin or 'Nvim'
  message = alternative and (message .. ', use ' .. alternative .. ' instead.') or message
  message = message
    .. ' See :h deprecated\nThis function will be removed in '
    .. plugin
    .. ' version '
    .. version
  if vim.notify_once(message, vim.log.levels.WARN) and backtrace ~= false then
    vim.notify(debug.traceback('', 2):sub(2), vim.log.levels.WARN)
  end
end

M.default_capabilities = function(override)
  override = override or {}

  return {
    textDocument = {
      completion = {
        completionItem = {
          snippetSupport = if_nil(override.snippetSupport, true),
          preselectSupport = if_nil(override.preselectSupport, true),
          insertReplaceSupport = if_nil(override.insertReplaceSupport, true),
          labelDetailsSupport = if_nil(override.labelDetailsSupport, true),
          deprecatedSupport = if_nil(override.deprecatedSupport, true),
          commitCharactersSupport = if_nil(override.commitCharactersSupport, true),
          tagSupport = if_nil(override.tagSupport, { valueSet = { 1 } }),
          resolveSupport = if_nil(override.resolveSupport, {
              properties = {
                  "documentation",
                  "detail",
                  "additionalTextEdits",
              },
          }),
        }
      },
    },
  }
end

---Backwards compatibility
M.update_capabilities = function(capabilities, override)
  local _deprecate = vim.deprecate or deprecate
  _deprecate('cmp_nvim_lsp.update_capabilities', 'cmp_nvim_lsp.default_capabilities', '1.0.0', 'cmp-nvim-lsp')
  return M.default_capabilities(override)
end


---Refresh sources on InsertEnter.
M._on_insert_enter = function()
  local cmp = require('cmp')

  local allowed_clients = {}

  -- register all active clients.
  for _, client in ipairs(vim.lsp.get_active_clients()) do
    allowed_clients[client.id] = client
    if not M.client_source_map[client.id] then
      local s = source.new(client)
      if s:is_available() then
        M.client_source_map[client.id] = cmp.register_source('nvim_lsp', s)
      end
    end
  end

  -- register all buffer clients (early register before activation)
  for _, client in ipairs(vim.lsp.buf_get_clients(0)) do
    allowed_clients[client.id] = client
    if not M.client_source_map[client.id] then
      local s = source.new(client)
      if s:is_available() then
        M.client_source_map[client.id] = cmp.register_source('nvim_lsp', s)
      end
    end
  end

  -- unregister stopped/detached clients.
  for client_id, source_id in pairs(M.client_source_map) do
    if not allowed_clients[client_id] or allowed_clients[client_id]:is_stopped() then
      cmp.unregister_source(source_id)
      M.client_source_map[client_id] = nil
    end
  end
end

return M
