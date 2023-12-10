# cmp-nvim-lsp

nvim-cmp source for neovim's built-in language server client.

## Capabilities

Language servers provide different completion results depending on the capabilities of the client. Neovim's default omnifunc has basic support for serving completion candidates. nvim-cmp supports more types of completion candidates, so users must override the capabilities sent to the server such that it can provide these candidates during a completion request. These capabilities are provided via the helper function `require('cmp_nvim_lsp').default_capabilities`

As these candidates are sent on each request, **adding these capabilities will break the built-in omnifunc support for neovim's language server client**. `nvim-cmp` provides manually triggered completion that can replace omnifunc. See `:help cmp-faq` for more details.

## Setup

```lua

require'cmp'.setup {
  sources = {
    { name = 'nvim_lsp' }
  }
}

-- The nvim-cmp almost supports LSP's capabilities so You should advertise it to LSP servers..
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- An example for configuring `clangd` LSP to use nvim-cmp as a completion engine
require('lspconfig').clangd.setup {
  capabilities = capabilities,
  ...  -- other lspconfig configs
}
```

## Option

`[%LSPCONFIG-NAME%].keyword_pattern`

You can override keyword_pattern for specific language-server like this.

```lua
cmp.setup {
  ...
  sources = {
    {
      name = 'nvim_lsp',
      option = {
        php = {
          keyword_pattern = [=[[\%(\$\k*\)\|\k\+]]=],
        }
      }
    }
  }
  ...
}
```


## Readme!

1. There is a Github issue that documents [breaking changes](https://github.com/hrsh7th/cmp-nvim-lsp/issues/38) for cmp-nvim-lsp. Subscribe to the issue to be notified of upcoming breaking changes.
2. This is my hobby project. You can support me via GitHub sponsors.
3. Bug reports are welcome, but don't expect a fix unless you provide minimal configuration and steps to reproduce your issue.
