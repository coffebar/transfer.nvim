describe("remote path resolving", function()
  local transfer = require("transfer")

  it("setup config", function()
    transfer.setup({
      config_template = [[
return {
  ["server1"] = {
    host = "server1",
    mappings = {
      {
        ["local"] = "example.com",
        ["remote"] = "/var/www/example.com",
      },
    },
    excludedPaths = {
      "src",
    },
  },
}
]],
    })

    local filereadable = vim.fn.filereadable(".nvim/deployment.lua")
    assert.equals(0, filereadable)
    vim.cmd("TransferInit")
    filereadable = vim.fn.filereadable(".nvim/deployment.lua")
    assert.equals(1, filereadable)
    vim.fn.delete(".nvim/deployment.lua")
  end)
end)
