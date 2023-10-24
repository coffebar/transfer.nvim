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

  vim.api.nvim_create_user_command("DiffRemote", function()
    local local_path = vim.fn.expand("%:p")
    local remote_path = require("transfer.transfer").remote_scp_path(local_path)
    if remote_path == nil then
      return
    end

    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = { remote_path },
      desc = "Add mapping to close diffview",
      once = true,
      callback = function()
        local config = require("transfer.config")
        if config.options.close_diffview_mapping == nil then
          return
        end
        vim.keymap.set("n", config.options.close_diffview_mapping, "<cmd>diffoff | bd!<cr>", { buffer = true })
      end,
    })

    vim.api.nvim_command("silent! diffsplit " .. remote_path)
  end, { nargs = 0 })

  -- TODO: create more commands here
end

return M
