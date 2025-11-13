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

local is_nvim_11_or_newer = vim.fn.has('nvim-0.11') == 1

--- Calls a method on a client object in a way that is compatible with both
--- Neovim 0.10 and 0.11+, handling the dot vs. colon syntax change for methods.
---
--- @param method_name string The name of the method to call (e.g., 'request').
--- @param ... any Variable arguments to be passed to the target method.
--- @return any The return value(s) from the called method.
source._call_client_method = function(self, method_name, ...)
  local method_func = self.client[method_name]

  if is_nvim_11_or_newer then
    -- Nvim 0.11+ requires the colon (:) syntax to avoid deprecation warnings.
    -- The call `obj:method(...)` is syntactic sugar for `obj.method(obj, ...)`.
    -- We replicate this by calling the function and passing the object `obj`
    -- as the first argument, followed by the rest of the arguments.
    return method_func(self.client, ...)
  else
    -- Nvim 0.10 requires the dot (.) syntax for methods with arguments,
    -- because a wrapper already injects the 'self' parameter.
    -- We just call the function directly with its arguments.
    return method_func(...)
  end
end

---Return the source is available.
---@return boolean
source.is_available = function(self)
  -- client is stopped.
  if self:_call_client_method('is_stopped') then
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
  if self:_call_client_method('is_stopped') then
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
  if self:_call_client_method('is_stopped') then
    return callback()
  end

  -- completion_item has no command.
  if not completion_item.command then
    return callback()
  end

  self:_request('workspace/executeCommand', completion_item.command, function(_, _)
    callback()
  end)
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
    self:_call_client_method('cancel_request', self.request_ids[method])
    self.request_ids[method] = nil
  end
  local _, request_id
  _, request_id = self:_call_client_method('request', method, params, function(arg1, arg2, arg3)
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
