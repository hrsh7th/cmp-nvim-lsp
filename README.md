# cmp-nvim-lsp

nvim-cmp source for neovim's built-in language server client.

# Capabilities

Language servers provide different completion results depending on the capabilities of the client. Neovim's default omnifunc has basic support for serving completion candidates. nvim-cmp supports more types of completion candidates, so users must override the capabilities sent to the server such that it can provide these candidates during a completion request. These capabilities are provided via the helper function `require('cmp_nvim_lsp').update_capabilities` 

As these candidates are sent on each request, **adding these capabilities will break the built-in omnifunc support for neovim's language server client**. `nvim-cmp` provides manually triggered completion that can replace omnifunc. See `:help cmp-faq` for more details.

# Setup

```lua

require'cmp'.setup {
  sources = {
    { name = 'nvim_lsp' }
  }
}

-- The nvim-cmp almost supports LSP's capabilities so You should advertise it to LSP servers..
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)

-- The following example advertise capabilities to `clangd`.
require'lspconfig'.clangd.setup {
  capabilities = capabilities,
}
```

