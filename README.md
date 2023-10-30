# transfer.nvim

## Description

Transfer.nvim is a Neovim plugin for syncing files with remote server using rsync and OpenSSH.

It supports mapping multiple local and remote paths, excluded path, and more.

## Install

### Lazy.nvim

```lua
{
  "coffebar/transfer.nvim",
  lazy = true,
  cmd = { "TransferInit", "DiffRemote", "TransferUpload", "TransferDownload", "TransferDirDiff", "TransferRepeat" },
  opts = {},
},
```

## Commands

- `TransferInit` - create a config file and open it. Just edit if it already exists.
- `DiffRemote` - open a diff view with the remote file.
- `TransferRepeat` - repeat the last transfer command (except TransferInit, DiffRemote).
- `TransferUpload [path]` - upload the given file or directory.
- `TransferDownload [path]` - download the given file or directory.
- `TransferDirDiff [path]` - diff the directory with the remote one and display the changed files in the quickfix.

## Deployment config example

```lua
{
  ["example_name"] = {
    host = "myhost",
    username = "web", -- optional
    mappings = {
      {
        ["local"] = "live", -- path relative to project root
        ["remote"] = "/var/www/example.com", -- absolute path
      },
      {
        ["local"] = "test",
        ["remote"] = "/var/www/test.example.com",
      },
    },
    excludedPaths = { -- optional
      "live/src/", -- local path relative to project root
      "test/src/",
    },
  },
}
```

Example `~/.ssh/config` for passwordless auth:

```ssh
Host myhost
  HostName 127.1.177.12
  User web
  IdentityFile ~/.ssh/myhost_key

Host server2
  ...
```

## Suggested mappings

### Neo-tree

```lua
{
  window = {
    mappings = {
      -- upload (sync files)
      uu = {
        function(state)
          vim.cmd("TransferUpload " .. state.tree:get_node().path)
        end,
        desc = "upload file or directory",
        nowait = true,
      },
      -- download (sync files)
      ud = {
        function(state)
          vim.cmd("TransferDownload" .. state.tree:get_node().path)
        end,
        desc = "download file or directory",
        nowait = true,
      },
      -- diff directory with remote
      uf = {
        function(state)
          local node = state.tree:get_node()
          local context_dir = node.path
          if node.type ~= "directory" then
            -- if not a directory
            -- one level up
            context_dir = context_dir:gsub("/[^/]*$", "")
          end
          vim.cmd("TransferDirDiff " .. context_dir)
          vim.cmd("Neotree close")
        end,
        desc = "diff with remote",
      },
    },
  },
}
```

### Which-key

```lua
require("which-key").register({
  ["<leader>"] = {
    u = {
      name = "Upload / Download",
      d = { "<cmd>TransferDownload<cr>", "Download from remote server (scp)" },
      u = { "<cmd>TransferUpload<cr>", "Upload to remote server (scp)" },
      f = { "<cmd>DiffRemote<cr>", "Diff file with remote server (scp)" },
      i = { "<cmd>TransferInit<cr>", "Init/Edit Deployment config" },
      r = { "<cmd>TransferRepeat<cr>", "Repeat transfer command" },
    },
  }
})
```

## Recommended to use with

- [rcarriga/nvim-notify](https://github.com/rcarriga/nvim-notify) - animated popup notifications.
- [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) - file explorer.
- [coffebar/neovim-project](https://github.com/coffebar/neovim-project) - project management.

## Migration from JetBrains config

[Check this repo](https://github.com/coffebar/jetbrains-deployment-config-to-lua) for converting you config from JetBrains projects.

## Config

[Look at defaults](https://github.com/coffebar/transfer.nvim/blob/main/lua/transfer/config.lua) and overwrite anything in your opts.


## Not tested or not working:

- Windows paths;
- SSH Auth that is not passwordless.

## Contributing

Feel free to open issues and PRs.

