local M = {}

M.setup = function()
  -- TransferInit - create a config file and open it. Just edit if it already exists
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

  -- DiffRemote - open a diff view with the remote file
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

  -- TransferUpload - upload the given file or directory
  vim.api.nvim_create_user_command("TransferUpload", function(opts)
    local path
    if opts ~= nil and opts.args then
      path = opts.args
    end
    if path == nil or path == "" then
      path = vim.fn.expand("%:p")
    end
    if vim.fn.isdirectory(path) == 1 then
      require("transfer.transfer").sync_dir(path, true)
    else
      require("transfer.transfer").upload_file(path)
    end
  end, { nargs = "?" })

  -- TransferDownload - download the given file or directory
  vim.api.nvim_create_user_command("TransferDownload", function(opts)
    local path
    if opts ~= nil and opts.args then
      path = opts.args
    end
    if path == nil or path == "" then
      path = vim.fn.expand("%:p")
    end
    if vim.fn.isdirectory(path) == 1 then
      require("transfer.transfer").sync_dir(path, false)
    else
      require("transfer.transfer").download_file(path)
    end
  end, { nargs = "?" })

  -- TransferDirDiff - show changed files between local and remote directory
  vim.api.nvim_create_user_command("TransferDirDiff", function(opts)
    local path
    if opts ~= nil and opts.args then
      path = opts.args
    end
    if path == nil or path == "" then
      path = vim.fn.expand("%:p")
    end
    require("transfer.transfer").show_dir_diff(path)
  end, { nargs = "?" })
end

return M
