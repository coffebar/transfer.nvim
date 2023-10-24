local transfer = require("transfer.transfer")
local config = require("transfer.config")
local commands = require("transfer.commands")

transfer.setup = function(opts)
  config.setup(opts)
  commands.setup()
end

return transfer
