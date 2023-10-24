local M = {}

M.defaults = {
  config_template = [[
return {
  ["server1"] = {
    host = "server1",
    mappings = {
      {
        ["local"] = "domains/example.com",
        ["remote"] = "/var/www/example.com",
      },
    },
    -- excludedPaths = {
    --   "src",
    -- },
  },
}
]],
  close_diffview_mapping = "<leader>b",
}

M.options = {}

M.setup = function(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
