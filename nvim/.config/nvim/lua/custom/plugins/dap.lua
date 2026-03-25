return {

    local dap = require 'dap'

dap.adapters.gdb = {
  type = 'executable',
  command = 'gdb',
  args = { '--interpreter=dap', '--quiet' },
}

dap.configurations.c = {
  {
    name = 'Launch',
    type = 'gdb',
    request = 'launch',
    program = function()
      return vim.fn.input('Path to exe:', vim.fn.getcwd() .. '/', 'file')
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = true,
  },
  }
}
