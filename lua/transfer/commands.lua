local M = {}

M.setup = function()
  -- add command to create a config file and open it
  vim.api.nvim_create_user_command("TransferInit", function()
    local config = require("transfer.config")
    local template = config.options.config_template
    local path = vim.loop.cwd() .. "/.nvim"
    if vim.fn.isdirectory(path) == 0 then
      vim.fn.mkdir(path)
    end
    path = path .. "/deployment.lua"
    if vim.fn.filereadable(path) == 0 then
      vim.fn.writefile(vim.fn.split(template, "\n"), path)
    end
    vim.cmd("edit " .. path)
  end, { nargs = 0 })

  -- TODO: create more commands here
end

return M
