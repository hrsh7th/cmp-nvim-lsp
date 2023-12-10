if vim.g.loaded_cmp_nvim_lsp then
  return
end
vim.g.loaded_cmp_nvim_lsp = true

require("cmp_nvim_lsp").setup()
