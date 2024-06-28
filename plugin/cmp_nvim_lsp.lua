if package.loaded["cmp_nvim_lsp"] then
  return
end

require("cmp_nvim_lsp").setup()
