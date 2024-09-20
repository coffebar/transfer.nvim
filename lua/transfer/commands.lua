local M = {}

M.recent_command = nil

local function create_autocmd()
  local augroup = vim.api.nvim_create_augroup("TransferNvim", { clear = true })
  vim.api.nvim_create_autocmd("DirChanged", {
    pattern = { "*" },
    group = augroup,
    desc = "Clear recent command after changing directory",
    callback = function()
      M.recent_command = nil
    end,
  })
end

local function get_config_path(is_local)
  if is_local then
    local dir = vim.loop.cwd() .. "/.nvim"
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir)
    end
    return dir .. "/deployment.lua"
  end
  return vim.fn.stdpath("data") .. "/deployment.lua"
end

M.setup = function()
  create_autocmd()

  -- TransferInit - create a local or global config file and open it. Just edit if it already exists
  vim.api.nvim_create_user_command("TransferInit", function(selected)
    local arg = selected.fargs[1] or "local"
    if arg ~= "local" and arg ~= "global" then
      vim.notify("Invalid argument: %s" .. arg, vim.log.levels.WARN, {
        title = "Transfer.nvim",
        icon = "",
      })
      return
    end
    local config = require("transfer.config")
    local template = arg == "local" and config.options.config_template_local or config.options.config_template_global
    -- if template is a function, call it
    if type(template) == "function" then
      template = template()
    end
    -- if template is a string, split it into lines
    if type(template) == "string" then
      template = vim.fn.split(template, "\n")
    end

    local path = get_config_path(arg == "local")
    if vim.fn.filereadable(path) == 0 then
      vim.fn.writefile(template, path)
    end
    vim.cmd("edit " .. path)
  end, { nargs = "?" })

  -- TransferRepeat - repeat the last transfer command
  vim.api.nvim_create_user_command("TransferRepeat", function()
    if M.recent_command == nil then
      vim.notify("No recent transfer command to repeat", vim.log.levels.WARN, {
        title = "Transfer.nvim",
        icon = "",
      })
      return
    end
    vim.cmd(M.recent_command)
  end, { nargs = 0 })

  -- DiffRemote - open a diff view with the remote file
  vim.api.nvim_create_user_command("DiffRemote", function()
    local local_path = vim.fn.expand("%:p")
    local remote_path = require("transfer.transfer").remote_scp_path(local_path)
    if remote_path == nil then
      return
    end

    local config = require("transfer.config")
    if config.options.close_diffview_mapping ~= nil then
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = { remote_path },
        desc = "Add mapping to close diffview",
        once = true,
        callback = function()
          vim.keymap.set("n", config.options.close_diffview_mapping, "<cmd>diffoff | bd!<cr>", { buffer = true })
        end,
      })
    end

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
    M.recent_command = "TransferUpload " .. path
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
    M.recent_command = "TransferDownload " .. path
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
    M.recent_command = "TransferDirDiff " .. path
    require("transfer.transfer").show_dir_diff(path)
  end, { nargs = "?" })
end

return M
