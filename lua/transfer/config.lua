local M = {}

M.defaults = {
  -- deployment config template: can be a string, a function or a table of lines
  config_template_local = [[
return {
  ["server1"] = {
    host = "server1",
    mappings = {
      {
        ["local"] = "domains/example.com", -- path relative to project root
        ["remote"] = "/var/www/example.com",
      },
    },
    -- excludedPaths = {
    --   "src", -- local path relative to project root
    -- },
  },
}
]],
  config_template_global = [[
return {
  ["server1"] = {
    host = "server1",
    mappings = {
      {
        ["local"] = "~/myproject/domains/example", -- absolute path to project root
        ["remote"] = "/var/www/example.com",
      },
    },
    -- excludedPaths = {
    --   "src", -- absolute path
    -- },
  },
}
]],
  close_diffview_mapping = "<leader>b", -- buffer related mapping to close diffview, set to nil to disable mapping
  upload_rsync_params = {
    "-rlzi",
    "--delete",
    "--checksum",
    "--exclude",
    ".git",
    "--exclude",
    ".idea",
    "--exclude",
    ".DS_Store",
    "--exclude",
    ".nvim",
    "--exclude",
    "*.pyc",
  },
  download_rsync_params = {
    "-rlzi",
    "--delete",
    "--checksum",
    "--exclude",
    ".git",
  },
}

M.options = {}

M.setup = function(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
