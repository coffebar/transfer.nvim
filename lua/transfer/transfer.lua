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
    neo_tree_command.execute({ action = "refresh" })
    return
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_call(bufnr, function()
      vim.api.nvim_command("edit")
    end)
  end
end

-- get the remote path for scp
-- @param local_path string
-- @return string
function M.remote_scp_path(local_path)
  local cwd = vim.loop.cwd()
  local config_file = cwd .. "/.nvim/deployment.lua"
  local file_exists = vim.fn.filereadable(config_file) == 1
  if not file_exists then
    vim.notify("No deployment config found in \n" .. config_file, vim.log.levels.ERROR, {
      title = "Error",
      icon = " ",
      timeout = 4000,
    })
    return nil
  end
  local deployment_conf = dofile(config_file)
  -- remove cwd from local file path
  local_path = local_path:gsub(cwd, ""):gsub("^/", "")

  local skip_reason
  for name, deployment in pairs(deployment_conf) do
    local skip = false
    for _, excluded in pairs(deployment.excludedPaths) do
      if string.find(local_path, excluded, 1, true) then
        skip_reason = "File is excluded from deployment on " .. name .. " by rule: " .. excluded
        skip = true
      end
    end
    if not skip then
      for _, mapping in pairs(deployment.mappings) do
        local start, e = string.find(local_path, mapping["local"], 1, true)
        if start == 1 then
          local remote_file = string.sub(local_path, e + 1)
          remote_file = mapping["remote"] .. remote_file
          remote_file = remote_file:gsub("^//", "/")
          local remote_path = "scp://"
          if deployment.username then
            remote_path = remote_path .. deployment.username .. "@"
          end
          remote_path = remote_path .. deployment.host
          if deployment.port and deployment.port ~= 22 then
            remote_path = remote_path .. ":" .. deployment.port
          end
          remote_path = remote_path .. "/" .. remote_file
          return remote_path
        end
      end
    end
  end
  if skip_reason == nil then
    skip_reason = "File is not mapped in deployment config"
  end
  vim.notify(skip_reason, vim.log.levels.ERROR, {
    title = "No matches found",
    icon = " ",
    timeout = 4000,
  })
  return nil
end

-- get the remote path for rsync
-- @param local_path string
-- @return string
function M.remote_rsync_path(local_path)
  local remote_path = M.remote_scp_path(local_path)
  if remote_path == nil then
    return
  end
  -- remove scp:// prefix from path
  remote_path = remote_path:gsub("^scp://", "")
  -- replace only the first occurrence of / with :
  remote_path = remote_path:gsub("/", ":", 1)
  return remote_path
end

return M
