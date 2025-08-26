# transfer.nvim

## Description

Transfer.nvim is a lightweight Neovim plugin that lets you manually **upload, download, and diff** files or directories between your local workspace and remote servers via **rsync** and **OpenSSH**.

It supports mapping multiple local and remote paths, excluded path, and more. 

Ideal for developers who prefer precise, command-driven deployment workflows. 

Suitable for small projects where there is no need for CI/CD.

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
-- .nvim/deployment.lua
return {
  ["example_name"] = {
    host = "myhost",
    username = "web", -- optional
    password = true, -- optional [string|true will prompt for password each time]
    mappings = {
      {
        ["local"] = "live", -- path relative to project root
        ["remote"] = "/var/www/example.com", -- absolute path or relative to user home
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
    upload_on_save = false
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
require("which-key").add({
  { "<leader>u", group = "Upload / Download", icon = "" },
  {
    "<leader>ud",
    "<cmd>TransferDownload<cr>",
    desc = "Download from remote server (scp)",
    icon = { color = "green", icon = "󰇚" },
  },
  {
    "<leader>uf",
    "<cmd>DiffRemote<cr>",
    desc = "Diff file with remote server (scp)",
    icon = { color = "green", icon = "" },
  },
  {
    "<leader>ui",
    "<cmd>TransferInit<cr>",
    desc = "Init/Edit Deployment config",
    icon = { color = "green", icon = "" },
  },
  {
    "<leader>ur",
    "<cmd>TransferRepeat<cr>",
    desc = "Repeat transfer command",
    icon = { color = "green", icon = "󰑖" },
  },
  {
    "<leader>uu",
    "<cmd>TransferUpload<cr>",
    desc = "Upload to remote server (scp)",
    icon = { color = "green", icon = "󰕒" },
  },
})
```

## Snacks.explorer (with lazy.nvim)

```lua
return {
  "coffebar/transfer.nvim",
  lazy = true,
  cmd = { "TransferInit", "DiffRemote", "TransferUpload", "TransferDownload", "TransferDirDiff", "TransferRepeat" },
  opts = {},
  dependencies = { 'folke/snacks.nvim' },
  specs = {
    {
      'folke/snacks.nvim',
      opts = {
        picker = {
          actions = {
            transfer_up = function(_, item)
              vim.cmd.TransferUpload(item.file)
            end,
            transfer_down = function(_, item)
              vim.cmd.TransferDownload(item.file)
            end,
            transfer_diff = function(_, item)
              if item.dir then
                vim.cmd.TransferDirDiff(item.file)
              else
                vim.cmd.DiffRemote(item.file)
              end
            end,
          },
          win = {
            list = {
              keys = {
                ['tu'] = 'transfer_up',
                ['td'] = 'transfer_down',
                ['tD'] = 'transfer_diff',
              }
            }
          }
        }
      }
    }
  }
}
```

## Recommended to use with

- [rcarriga/nvim-notify](https://github.com/rcarriga/nvim-notify) - animated popup notifications.
- [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) - file explorer.
- [coffebar/neovim-project](https://github.com/coffebar/neovim-project) - project management.

## Migration from JetBrains config

[Check this repo](https://github.com/coffebar/jetbrains-deployment-config-to-lua) for converting you config from JetBrains projects.

## Config

[Look at defaults](https://github.com/coffebar/transfer.nvim/blob/main/lua/transfer/config.lua) and overwrite anything in your opts.

## Demo video

https://github.com/coffebar/transfer.nvim/assets/3100053/32cb642a-9040-47dd-a661-4058869c79f1

## Not tested or not working:

- Windows paths;

## Contributing

Feel free to contribute, open issues, and submit pull requests to help us improve transfer.nvim.

Run tests with `make test`.

Follow the Conventional Commits specification for commit naming.

## Related projects

- [KenN7/vim-arsync](https://github.com/KenN7/vim-arsync)
- [OscarCreator/rsync.nvim](https://github.com/OscarCreator/rsync.nvim)

