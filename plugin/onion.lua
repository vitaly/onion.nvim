if vim.g.loaded_onion then
  return
end
vim.g.loaded_onion = true

require('onion.commands').setup()
