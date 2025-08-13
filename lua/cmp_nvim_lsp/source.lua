local source = {}

source.new = function(client)
  local self = setmetatable({}, { __index = source })
  self.client = client
  self.request_ids = {}
  return self
end

---Get debug name.
---@return string
source.get_debug_name = function(self)
  return table.concat({ 'nvim_lsp', self.client.name }, ':')
end

---Return the source is available.
---@return boolean
source.is_available = function(self)
  -- client is stopped.
  if self.client:is_stopped() then
    return false
  end

  -- client is not attached to current buffer.
  local bufnr = vim.api.nvim_get_current_buf()
  local get_clients = (
    vim.lsp.get_clients ~= nil and vim.lsp.get_clients -- nvim 0.10+
    or vim.lsp.get_active_clients
  )
  if vim.tbl_isempty(get_clients({ bufnr = bufnr, id = self.client.id })) then
    return false
  end

  -- client has no completion capability.
  if not self:_get(self.client.server_capabilities, { 'completionProvider' }) then
    return false
  end
  return true;
end

---Get LSP's PositionEncodingKind.
---@return lsp.PositionEncodingKind
source.get_position_encoding_kind = function(self)
  return self:_get(self.client.server_capabilities, { 'positionEncoding' }) or self.client.offset_encoding or 'utf-16'
end

---Get triggerCharacters.
---@return string[]
source.get_trigger_characters = function(self)
  return self:_get(self.client.server_capabilities, { 'completionProvider', 'triggerCharacters' }) or {}
end

---Get get_keyword_pattern.
---@param params cmp.SourceApiParams
---@return string
source.get_keyword_pattern = function(self, params)
  local option
  option = params.option or {}
  option = option[self.client.name] or {}
  return option.keyword_pattern or require('cmp').get_config().completion.keyword_pattern
end

---Resolve LSP CompletionItem.
---@param params cmp.SourceCompletionApiParams
---@param callback function
source.complete = function(self, params, callback)
  local lsp_params = vim.lsp.util.make_position_params(0, self.client.offset_encoding)
  lsp_params.context = {}
  lsp_params.context.triggerKind = params.completion_context.triggerKind
  lsp_params.context.triggerCharacter = params.completion_context.triggerCharacter
  self:_request('textDocument/completion', lsp_params, function(_, response)
    callback(response)
  end)
end

---Resolve LSP CompletionItem.
---@param completion_item lsp.CompletionItem
---@param callback function
source.resolve = function(self, completion_item, callback)
  -- client is stopped.
  if self.client:is_stopped() then
    return callback()
  end

  -- client has no completion capability.
  if not self:_get(self.client.server_capabilities, { 'completionProvider', 'resolveProvider' }) then
    return callback()
  end

  self:_request('completionItem/resolve', completion_item, function(_, response)
    callback(response or completion_item)
  end)
end

---Execute LSP CompletionItem.
---@param completion_item lsp.CompletionItem
---@param callback function
source.execute = function(self, completion_item, callback)
  -- client is stopped.
  if self.client:is_stopped() then
    return callback()
  end

  -- completion_item has no command.
  local command = completion_item.command
  if not command then
    return callback()
  end

  -- The logic below is taken from the following and is slightly modified.
  -- https://github.com/neovim/neovim/blob/f72dc2b4c805f309f23aff62b3e7ba7b71a554d2/runtime/lua/vim/lsp/client.lua#L864-L905
  local bufnr = vim.api.nvim_get_current_buf()
  local f = self.client.commands[command.command] or vim.lsp.commands[command.command]
  if f then
    f(command, { bufnr = bufnr, client_id = self.client.id })
    callback()
    return
  end

  local command_provider = self.client.server_capabilities.executeCommandProvider
  local commands = type(command_provider) == 'table' and command_provider.commands or {}
  if not vim.list_contains(commands, command.command) then
    vim.notify_once(
      string.format(
        'cmp_nvim_lsp: Language server `%s` does not support command `%s`. This command may require a client extension.',
        self.client.name,
        command.command
      ),
      vim.log.levels.WARN
    )
    callback()
    return
  end

  -- Not using command directly to exclude extra properties,
  -- see https://github.com/python-lsp/python-lsp-server/issues/146
  local params = {
    command = command.command,
    arguments = command.arguments,
  }
  self.client.request(vim.lsp.protocol.Methods.workspace_executeCommand, params, function()
    callback()
  end, bufnr)
end

---Get object path.
---@param root table
---@param paths string[]
---@return any
source._get = function(_, root, paths)
  local c = root
  for _, path in ipairs(paths) do
    c = c[path]
    if not c then
      return nil
    end
  end
  return c
end

---Send request to nvim-lsp servers with backward compatibility.
---@param method string
---@param params table
---@param callback function
source._request = function(self, method, params, callback)
  if self.request_ids[method] ~= nil then
    self.client:cancel_request(self.request_ids[method])
    self.request_ids[method] = nil
  end
  local _, request_id
  _, request_id = self.client:request(method, params, function(arg1, arg2, arg3)
    if self.request_ids[method] ~= request_id then
      return
    end
    self.request_ids[method] = nil

    -- Text changed, retry
    if arg1 and arg1.code == -32801 then
      self:_request(method, params, callback)
      return
    end

    if method == arg2 then
      callback(arg1, arg3) -- old signature
    else
      callback(arg1, arg2) -- new signature
    end
  end)
  self.request_ids[method] = request_id
end

return source
