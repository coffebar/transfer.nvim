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

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    desc = "Upload on Save",
    callback = function(args)
      require("transfer.transfer").upload_on_save(args.file)
    end,
  })
end

M.setup = function()
  create_autocmd()

  -- TransferInit - create a config file and open it. Just edit if it already exists
  vim.api.nvim_create_user_command("TransferInit", function()
    local config = require("transfer.config")
    local template = config.options.config_template
    -- if template is a function, call it
    if type(template) == "function" then
      template = template()
    end
    -- if template is a string, split it into lines
    if type(template) == "string" then
      template = vim.fn.split(template, "\n")
    end
    local path = vim.loop.cwd() .. "/.nvim"
    if vim.fn.isdirectory(path) == 0 then
      vim.fn.mkdir(path)
    end
    path = path .. "/deployment.lua"
    if vim.fn.filereadable(path) == 0 then
      vim.fn.writefile(template, path)
    end
    vim.cmd("edit " .. path)
  end, { nargs = 0 })

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
  vim.api.nvim_create_user_command("DiffRemote", function(opts)
    local local_path
    if opts ~= nil and opts.args then
      local_path = opts.args
    end
    if local_path == nil or local_path == "" then
      local_path = vim.fn.expand("%:p")
    end
    local remote_path = require("transfer.transfer").remote_scp_path(local_path)
    if remote_path == nil then
      return
    end

    local config = require("transfer.config")
    local orig_win = vim.api.nvim_get_current_win()

    if config.options.close_diffview_mapping ~= nil then
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = { remote_path },
        desc = "Add mapping to close diffview",
        once = true,
        callback = function()
          vim.keymap.set("n", config.options.close_diffview_mapping, function()
            if vim.api.nvim_win_is_valid(orig_win) then
              vim.api.nvim_win_call(orig_win, function()
                vim.cmd("diffoff")
              end)
            end
            vim.cmd("diffoff")
            vim.cmd("bd!")
          end, { buffer = true, desc = "Close Diffview" })
        end,
      })
    end
    vim.api.nvim_command("silent! diffsplit " .. remote_path)
  end, { nargs = "?" })

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
