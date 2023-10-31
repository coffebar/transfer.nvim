describe("remote path resolving", function()
  local transfer = require("transfer")

  local function remote_scp_path(local_path)
    local path, _ = transfer.remote_scp_path(local_path)
    return path
  end

  local function remote_rsync_path(local_path)
    local path, _ = transfer.remote_rsync_path(local_path)
    return path
  end

  it("init config", function()
    transfer.setup({
      config_template = "return {}",
    })

    local filereadable = vim.fn.filereadable(".nvim/deployment.lua")
    assert.equals(0, filereadable)
    vim.cmd("TransferInit")
    filereadable = vim.fn.filereadable(".nvim/deployment.lua")
    assert.equals(1, filereadable)
    vim.fn.delete(".nvim/deployment.lua")
  end)

  it("scp", function()
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
      {
        ["local"] = "",
        ["remote"] = "",
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
    -- remote_scp_path
    local cwd = vim.loop.cwd()
    assert.equals("scp://server1//var/www/example.com", remote_scp_path("example.com"))
    assert.equals("scp://server1//var/www/example.com/index.js", remote_scp_path(cwd .. "/example.com/index.js"))
    assert.equals("scp://server1/Docker", remote_scp_path(cwd .. "/Docker"))
    assert.equals("scp://server1/doc/", remote_scp_path(cwd .. "/doc/"))
    assert.equals(nil, remote_scp_path(cwd .. "/src/secret"))
    assert.equals(nil, remote_scp_path("/src/secret"))

    vim.fn.delete(".nvim/deployment.lua")
  end)

  it("rsync", function()
    transfer.setup({
      config_template = [[
return {
  ["server2"] = {
    host = "server2",
    mappings = {
      {
        ["local"] = "domain/test",
        ["remote"] = "test.com",
      },
      {
        ["local"] = "domain/test2/",
        ["remote"] = "/srv/example.com/",
      },
    },
    excludedPaths = {
      "domain/test2/.git",
    },
  },
}
]],
    })

    local filereadable = vim.fn.filereadable(".nvim/deployment.lua")
    assert.equals(0, filereadable)
    vim.cmd("TransferInit")
    filereadable = vim.fn.filereadable(".nvim/deployment.lua")
    assert.equals(filereadable, 1)
    local cwd = vim.loop.cwd()
    assert.equals(nil, remote_rsync_path(cwd .. "/.git"))
    assert.equals(nil, remote_rsync_path(cwd .. "/.nvim"))
    assert.equals(nil, remote_rsync_path(cwd .. "/.idea"))
    assert.equals("server2:test.com/", remote_rsync_path(cwd .. "/domain/test/"))
    assert.equals("server2:test.com/dir", remote_rsync_path(cwd .. "/domain/test/dir"))
    assert.equals(nil, remote_rsync_path(cwd .. "/dir/domain/test/"))
    assert.equals(nil, remote_rsync_path(cwd .. "/domain/test2/.git"))
    assert.equals("server2:/srv/example.com", remote_rsync_path(cwd .. "/domain/test2"))
    assert.equals("server2:/srv/example.com/dir/", remote_rsync_path(cwd .. "/domain/test2/dir/"))
    assert.equals("server2:/srv/example.com/.github", remote_rsync_path(cwd .. "/domain/test2/.github"))

    vim.fn.delete(".nvim/deployment.lua")
  end)
end)
