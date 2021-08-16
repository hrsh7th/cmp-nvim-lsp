local source = {}

source.new = function(client)
  local self = setmetatable({}, { __index = source })
  self.client = client
  self.request_id = nil
  self.resolve_request_id = nil
  self.execute_request_id = nil
  return self
end

source.get_debug_name = function(self)
  return table.concat({ 'nvim_lsp', self.client.name }, ':')
end

source.get_trigger_characters = function(self)
  return self:_get(self.client.server_capabilities, { 'completionProvider', 'triggerCharacters' }) or {}
end

source.complete = function(self, request, callback)
  -- client is stopped.
  if self.client.is_stopped() then
    return callback()
  end

  -- client is not attached to current buffer.
  if not vim.lsp.buf_get_clients(request.context.bufnr)[self.client.id] then
    return callback()
  end

  -- client has no completion capability.
  if not self:_get(self.client.server_capabilities, { 'completionProvider' }) then
    return callback()
  end

  local params = vim.lsp.util.make_position_params()
  params.context = {}
  params.context.triggerKind = request.completion_context.triggerKind
  params.context.triggerCharacter = request.completion_context.triggerCharacter

  if self.request_id ~= nil then
    self.client.cancel_request(self.request_id)
  end

  local _, request_id
  _, request_id = self.client.request('textDocument/completion', params, function(_, _, response)
    if self.request_id ~= request_id then
      return
    end
    callback(response)
  end)
  self.request_id = request_id
end

source.resolve = function(self, completion_item, callback)
  -- client is stopped.
  if self.client.is_stopped() then
    return callback()
  end

  -- client has no completion capability.
  if not self:_get(self.client.server_capabilities, { 'completionProvider', 'resolveProvider' }) then
    return callback()
  end

  if self.resolve_request_id ~= nil then
    self.client.cancel_request(self.resolve_request_id)
  end
  local _, resolve_request_id
  _, resolve_request_id = self.client.request('completionItem/resolve', completion_item, function(_, _, response)
    if self.resolve_request_id ~= resolve_request_id then
      return
    end
    callback(response)
  end)
  self.resolve_request_id = resolve_request_id
end

source.execute = function(self, completion_item, callback)
  -- client is stopped.
  if self.client.is_stopped() then
    return callback()
  end

  -- completion_item has no command.
  if not completion_item.command then
    callback()
  end

  if self.execute_request_id ~= nil then
    self.client.cancel_request(self.execute_request_id)
  end
  local _, execute_request_id
  _, execute_request_id = self.client.request('workspace/executeCommand', completion_item.command, function(_, _, _)
    if self.execute_request_id ~= execute_request_id then
      return
    end
    callback()
  end)
  self.execute_request_id = execute_request_id
end

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

return source
