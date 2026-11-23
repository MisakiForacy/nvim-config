-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- 全局 4 空格：C++ / Python 都吃这个规矩
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- 不写 swap 文件：有 undofile（撤销历史）和 persistence 会话就够了，
-- 免得强退后留下一堆 .swp，下次打开弹 E325
vim.opt.swapfile = false

-- 剪贴板不用管：LazyVim 默认已经设了 clipboard=unnamedplus（非 SSH 环境）