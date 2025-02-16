local config = require("transfer.config")

local M = {}

-- reloads the buffer after a transfer
-- refreshes the neo-tree if the buffer is a neo-tree
-- @param bufnr number
-- @return void
local function reload_buffer(bufnr)
  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
  if filetype == "neo-tree" then
    local installed, neo_tree_command = pcall(require, "neo-tree.command")
    if installed then
      neo_tree_command.execute({ action = "refresh" })
    end
    return
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_call(bufnr, function()
      vim.api.nvim_command("edit!")
    end)
  end
end

-- convert the given local absolute path to a relative project root path
-- @param absolute_path string
-- @return string
local function normalize_local_path(absolute_path)
  local cwd = vim.loop.cwd()
  local found, found_end = string.find(absolute_path, cwd, 1, true)
  if found == 1 then
    absolute_path = string.sub(absolute_path, found_end + 1)
  end
  -- remove leading slash
  return string.gsub(absolute_path, "^/", "")
end

-- check if the given path matches the given pattern
-- @param path string
-- @param pattern string
-- @return boolean
local function path_matches(path, pattern)
  pattern = string.gsub(pattern, "/$", "")
  path = string.gsub(path, "/$", "")
  local s, e = string.find(path, pattern, 1, true)
  if s ~= 1 then
    return false
  end
  if e == #path then
    return true
  end
  local next_char = string.sub(path, e + 1, e + 1)
  if next_char == "/" then
    return true
  end
  return false
end

-- get the remote path for scp
-- @param deployment table
-- @param remote_file string
-- @return string
local function build_scp_path(deployment, remote_file)
  local remote_path = "scp://"
  if deployment.username then
    remote_path = remote_path .. deployment.username .. "@"
  end
  remote_file = string.gsub(remote_file, "\\", "/")
  remote_path = remote_path .. deployment.host
  remote_path = remote_path .. "/" .. remote_file
  return remote_path
end

-- get the excluded paths for the given directory
-- @param deployment table
-- @param dir string
-- @return table
function M.excluded_paths_for_dir(deployment, dir)
  local excludedPaths = {}
  if deployment and deployment.excludedPaths and #deployment.excludedPaths > 0 then
    -- remove cwd from local file path
    local local_path = normalize_local_path(dir)
    for _, excluded in pairs(deployment.excludedPaths) do
      excluded = string.gsub(excluded, "^/", "")
      if path_matches(excluded, local_path) then
        local s, e = string.find(excluded, local_path, 1, true)
        if s then
          excluded = string.sub(excluded, e + 1)
          excluded = string.gsub(excluded, "^/", "")
          table.insert(excludedPaths, excluded)
        end
      elseif not excluded:find("/") and excluded:find("*") then
        -- pattern
        table.insert(excludedPaths, excluded)
      end
    end
  end
  return excludedPaths
end

-- get the remote path for scp
-- @param local_path string
-- @return string
function M.remote_scp_path(local_path)
  local cwd = vim.loop.cwd()
  local config_file = cwd .. "/.nvim/deployment.lua"
  if vim.fn.filereadable(config_file) ~= 1 then
    vim.notify(
      "No deployment config found in \n" .. config_file .. "\n\nRun `:TransferInit` to create it",
      vim.log.levels.WARN,
      {
        title = "Transfer.nvim",
        icon = " ",
        timeout = 4000,
      }
    )
    return nil
  end
  local deployment_conf = dofile(config_file)
  -- remove cwd from local file path
  local_path = normalize_local_path(local_path)

  local skip_reason
  for name, deployment in pairs(deployment_conf) do
    local skip = false
    if deployment.excludedPaths ~= nil then
      for _, excluded in pairs(deployment.excludedPaths) do
        excluded = string.gsub(excluded, "^/", "")
        if path_matches(local_path, excluded) then
          skip_reason = "File is excluded from deployment\non " .. name .. " by rule: " .. excluded
          skip = true
        end
      end
    end
    if not skip then
      for _, mapping in pairs(deployment.mappings) do
        -- handle mappings like nil, "" or "/" as same thing
        local mapped = mapping["local"]
        local remote_file = nil
        if mapped == nil or mapped == "" or mapped == "/" or mapped == "." then
          if mapping["remote"] == nil or mapping["remote"] == "" or mapping["remote"] == "/" then
            remote_file = local_path
          else
            remote_file = mapping["remote"]
            if remote_file:sub(-1) ~= "/" and local_path ~= "" then
              remote_file = remote_file .. "/"
            end
            remote_file = remote_file .. local_path
          end
          return build_scp_path(deployment, remote_file), deployment
        else
          if path_matches(local_path, mapped) then
            if local_path:sub(-1) == "/" and mapped:sub(-1) ~= "/" then
              -- if local_path ends with a slash, and mapped does not, add it
              mapped = mapped .. "/"
            end
            if local_path == mapped then
              remote_file = mapping["remote"]
            else
              remote_file = mapping["remote"] .. string.sub(local_path, #mapped + 1)
            end
            -- align trailing slashes with input
            if local_path:sub(-1) == "/" and remote_file:sub(-1) ~= "/" then
              remote_file = remote_file .. "/"
            elseif local_path:sub(-1) ~= "/" and remote_file:sub(-1) == "/" then
              remote_file = remote_file:sub(1, #remote_file - 1)
            end
          end
        end
        if remote_file ~= nil then
          return build_scp_path(deployment, remote_file), deployment
        end
      end
    end
  end
  if skip_reason == nil then
    skip_reason = "File '" .. local_path .. "'\nis not mapped in deployment config"
  end
  vim.notify(skip_reason, vim.log.levels.ERROR, {
    title = "No mappings found",
    icon = " ",
    timeout = 4000,
  })
  return nil
end

-- get the remote path for rsync
-- @param local_path string
-- @return string
function M.remote_rsync_path(local_path)
  local remote_path, deployment = M.remote_scp_path(local_path)
  if remote_path == nil then
    return
  end
  -- remove scp:// prefix from path
  remote_path = remote_path:gsub("^scp://", "")
  -- replace only the first occurrence of / with :
  remote_path = remote_path:gsub("/", ":", 1)
  return remote_path, deployment
end

-- upload the given file
-- @param local_path string
-- @return void
function M.upload_file(local_path)
  if local_path == nil then
    local_path = vim.fn.expand("%:p")
  else
    local_path = vim.fn.fnamemodify(local_path, ":p")
  end
  local remote_path, deployment = M.remote_scp_path(local_path)
  if remote_path == nil then
    return
  end
  local local_pwd, remote_pwd
  if config.options.notification and config.options.notification.use_cwd then
    local_pwd = vim.fn.fnamemodify(local_path, ":."):gsub(".*/", "")
    remote_pwd = local_pwd
  else
    local_pwd = vim.fn.fnamemodify(local_path, ":~"):gsub(".*/", "")
    remote_pwd = remote_path
  end
  local stderr = {}
  local notification = vim.notify(local_pwd, vim.log.levels.INFO, {
    title = "Uploading file...",
    timeout = 0,
    icon = "󱕌 ",
  })
  local notification_id
  if type(notification) == "table" and notification.id then
      notification_id = notification.id
  elseif type(notification) == "number" then
      notification_id = notification
  end
  vim.fn.jobstart({ "scp", local_path, remote_path }, {
    pty = true,
    on_stdout = function(cid, data, _)
      if string.find(table.concat(data, "\n"), 'password') then
        if deployment.password then
          vim.fn.chansend(cid, deployment.password .. '\n')
        else
          local password = vim.fn.input('Password')
          vim.fn.chansend(cid, password .. '\n')
        end
      end
    end,
    on_stderr = function(_, data, _)
      vim.notify(local_pwd, vim.log.levels.INFO, {
        title = data,
        timeout = 0,
        icon = "󱕌 ",
      })
      if data == nil or #data == 0 then
        return
      end
      vim.list_extend(stderr, data)
    end,
    on_exit = function(_, code, _)
      if code == 0 then
        vim.notify(remote_pwd, vim.log.levels.INFO, {
          id = notification_id,
          title = "File uploaded",
          icon = "",
          timeout = 3000,
          replace = notification_id,
        })
      else
        local message
        if stderr == nil or #stderr == 0 then
          message = nil
        else
          message = table.concat(stderr, "\n")
        end
        vim.notify(message, vim.log.levels.ERROR, {
          id = notification_id,
          title = "Error uploading file",
          timeout = 4000,
          replace = notification_id,
          icon = " ",
        })
      end
    end,
  })
end

-- Replace local file with remote copy
-- @param local_path string|nil
function M.download_file(local_path)
  if local_path == nil then
    local_path = vim.fn.expand("%:p")
  else
    local_path = vim.fn.fnamemodify(local_path, ":p")
  end
  local remote_path, deployment = M.remote_scp_path(local_path)
  if remote_path == nil then
    return
  end
  local local_pwd, remote_pwd
  if config.options.notification and config.options.notification.use_cwd then
    local_pwd = vim.fn.fnamemodify(local_path, ":."):gsub(".*/", "")
    remote_pwd = local_pwd
  else
    local_pwd = vim.fn.fnamemodify(local_path, ":~"):gsub(".*/", "")
    remote_pwd = remote_path
  end

  local notification = vim.notify(local_pwd, vim.log.levels.INFO, {
    title = "Downloading file...",
    timeout = 0,
    icon = "󱕉 ",
  })
  local notification_id
  if type(notification) == "table" and notification.id then
      notification_id = notification.id
  elseif type(notification) == "number" then
      notification_id = notification
  end
  local stderr = {}
  vim.fn.jobstart({ "scp", remote_path, local_path }, {
    pty = true,
    on_stdout = function(cid, data, _)
      if string.find(table.concat(data, "\n"), 'password') then
        if deployment.password then
          vim.fn.chansend(cid, deployment.password .. '\n')
        else
          local password = vim.fn.input('Password')
          vim.fn.chansend(cid, password .. '\n')
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data == nil or #data == 0 then
        return
      end
      vim.list_extend(stderr, data)
    end,
    on_exit = function(_, code, _)
      if code == 0 then
        vim.notify(remote_pwd, vim.log.levels.INFO, {
          id = notification_id,
          title = "Remote file downloaded",
          icon = "",
          timeout = 1000,
          replace = notification_id,
        })
        -- reload buffer for the downloaded file
        local bufnr = vim.fn.bufnr(local_path)
        if bufnr ~= -1 then
          reload_buffer(bufnr)
        end
      else
        local message
        if stderr == nil or #stderr == 0 then
          message = nil
        else
          message = table.concat(stderr, "\n")
        end
        vim.notify(message, vim.log.levels.ERROR, {
          id = notification_id,
          title = "Error downloading file",
          icon = " ",
          timeout = 4000,
          replace = notification_id,
        })
      end
    end,
  })
end

-- Sync local and remote directory
-- @param dir string
-- @param upload boolean
function M.sync_dir(dir, upload)
  local remote_path, deployment = M.remote_rsync_path(dir)
  if remote_path == nil then
    return
  end

  local excluded = M.excluded_paths_for_dir(deployment, dir)

  local cmd = { "rsync" }
  if upload then
    vim.list_extend(cmd, config.options.upload_rsync_params)
    for _, path in pairs(excluded) do
      vim.list_extend(cmd, { "--exclude", path })
    end
    vim.list_extend(cmd, { dir .. "/", remote_path .. "/" })
  else
    for _, path in pairs(excluded) do
      vim.list_extend(cmd, { "--exclude", path })
    end
    vim.list_extend(cmd, config.options.download_rsync_params)
    vim.list_extend(cmd, { remote_path .. "/", dir .. "/" })
  end

  local notification = vim.notify("rsync: " .. remote_path, vim.log.levels.INFO, {
    title = "Sync started...",
    icon = " ",
    timeout = 5000,
  })
  local notification_id
  if type(notification) == "table" and notification.id then
      notification_id = notification.id
  elseif type(notification) == "number" then
      notification_id = notification
  end
  local output = {}
  local stderr = {}
  vim.fn.jobstart(cmd, {
    pty = true,
    on_stdout = function(cid, data, _)
      if string.find(table.concat(data, "\n"), 'password') then
        if deployment.password then
          vim.fn.chansend(cid, deployment.password .. '\n')
        else
          local password = vim.fn.input('Password')
          vim.fn.chansend(cid, password .. '\n')
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data == nil or #data == 0 then
        return
      end
      vim.list_extend(stderr, data)
    end,
    on_stdout = function(_, data, _)
      for _, line in pairs(data) do
        if line ~= "" then
          table.insert(output, line)
        end
      end
    end,
    on_exit = function(_, code, _)
      if code ~= 0 then
        local message
        if stderr == nil or #stderr == 0 then
          message = nil
        else
          message = table.concat(stderr, "\n")
        end
        vim.notify(message, vim.log.levels.ERROR, {
          id = notification_id,
          timeout = 10000,
          title = "Error running rsync",
          icon = " ",
          replace = notification_id,
        })
        return
      end

      if not upload then
        local filetype = vim.api.nvim_buf_get_option(0, "filetype")
        if filetype == "neo-tree" then
          reload_buffer(0)
        end
        -- reload all buffers in the synced directory
        local buffers = vim.api.nvim_list_bufs()
        for _, bufnr in pairs(buffers) do
          local bufname = vim.api.nvim_buf_get_name(bufnr)
          if bufname ~= "" and bufname:find(dir, 1, true) then
            reload_buffer(bufnr)
          end
        end
      end

      if #output == 0 then
        output = { "No differences found" }
      end
      vim.notify(table.concat(output, "\n"), vim.log.levels.INFO, {
        id = notification_id,
        timeout = 3000,
        title = "Sync completed",
        icon = " ",
        replace = notification_id,
      })
    end,
  })
end

function M.show_dir_diff(dir)
  local remote_path, deployment = M.remote_rsync_path(dir)
  if remote_path == nil then
    return
  end

  local excluded = M.excluded_paths_for_dir(deployment, dir)
  local cmd = { "rsync", "-rlzi", "--dry-run", "--checksum", "--delete", "--out-format=%n" }
  for _, path in pairs(excluded) do
    vim.list_extend(cmd, { "--exclude", path })
  end

  if config.options.upload_rsync_params ~= nil then
    for i, v in ipairs(config.options.upload_rsync_params) do
      if v == "--exclude" then
        if i + 1 > #config.options.upload_rsync_params then
          break
        end
        vim.list_extend(cmd, { v, config.options.upload_rsync_params[i + 1] })
      end
    end
  end

  local lines = { " " .. table.concat(cmd, " ") }
  vim.list_extend(cmd, { dir .. "/", remote_path .. "/" })

  local notification = vim.notify("rsync -rlzi --dry-run --checksum --delete", vim.log.levels.INFO, {
    title = "Diff started...",
    icon = " ",
    timeout = 3500,
  })
  local notification_id
  if type(notification) == "table" and notification.id then
      notification_id = notification.id
  elseif type(notification) == "number" then
      notification_id = notification
  end
  vim.list_extend(lines, { normalize_local_path(dir), remote_path, "------" })
  local output = {}
  local stderr = {}
  vim.fn.jobstart(cmd, {
    pty = true,
    on_stdout = function(cid, data, _)
      if string.find(table.concat(data, "\n"), 'password') then
        if deployment.password then
          vim.fn.chansend(cid, deployment.password .. '\n')
        else
          local password = vim.fn.input('Password')
          vim.fn.chansend(cid, password .. '\n')
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data == nil or #data == 0 then
        return
      end
      vim.list_extend(stderr, data)
    end,
    on_stdout = function(_, data, _)
      for _, line in pairs(data) do
        if line ~= "" then
          line = line:gsub("^deleting ", " ")
          table.insert(output, line)
        end
      end
    end,
    on_exit = function(_, code, _)
      if code ~= 0 then
        vim.notify(table.concat(stderr, "\n"), vim.log.levels.ERROR, {
          id = notification_id,
          timeout = 10000,
          title = "Error running rsync",
          icon = " ",
          replace = notification_id,
        })
        return
      end
      if #output == 0 then
        table.insert(lines, " No differences found")
      else
        vim.list_extend(lines, output)
      end
      -- show quickfix list
      vim.fn.setqflist({}, "r", { title = "Diff: " .. dir, lines = lines })
      vim.api.nvim_command("copen")
    end,
  })
end

return M
