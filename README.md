# transfer.nvim

## Description

Transfer.nvim is a plugin for syncing files with remote server using rsync and OpenSSH.

It supports mapping multiple local and remote paths, excluded path, and more.

## Install

### Lazy.nvim

```lua
{
    "coffebar/transfer.nvim",
    lazy = true,
    cmd = { "TransferInit", "DiffRemote", "TransferUpload", "TransferDownload", "TransferDirDiff" },
    opts = {},
},
```

## Recommended to use with

- `rcarriga/nvim-notify` - animated popup notifications
- `nvim-neo-tree/neo-tree.nvim` - file explorer
- `coffebar/neovim-project` - project management

## Commands

- `TransferInit` - create a config file and open it. Just edit if it already exists
- `DiffRemote` - open a diff view with the remote file
- `TransferUpload [path]` - upload the given file or directory
- `TransferDownload [path]` - download the given file or directory
- `TransferDirDiff [path]` - diff the current directory with the remote one (show changed files in qf window)


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
            ["<c-d>"] = {
                function(state)
                    vim.cmd("TransferDirDiff " .. state.tree:get_node().path)
                    vim.cmd("Neotree close")
                    end,
                desc = "diff with remote",
            },
        }
    }
}
```

### Which-key

```lua
wk.register({
    ["<leader>"] = {
      u = {
        name = "Upload / Download",
        d = { "<cmd>TransferDownload<cr>", "Download from remote server (scp)" },
        u = { "<cmd>TransferUpload<cr>", "Upload to remote server (scp)" },
        f = { "<cmd>DiffRemote<cr>", "Diff file with remote server (scp)" },
        i = { "<cmd>TransferInit<cr>", "Init/Edit Deployment config" },
      },
    }
})
```

## Migration from IDEA config

[Check this repo](https://github.com/coffebar/jetbrains-deployment-config-to-lua) for converting you config from jetbrains projects.

## Config

[Look at defaults](https://github.com/coffebar/transfer.nvim/blob/main/lua/transfer/config.lua) and overwrite anything in your opts.


## Not tested or not working:

- Windows paths;
- SSH Auth that is not passwordless.

## Contributing

Feel free to open issues and PRs.

