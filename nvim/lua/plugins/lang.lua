return {
  -- 打开 LazyVim 的 C/C++ 支持：clangd + clangd_extensions
  -- 顺带给 nvim-treesitter 装上 cpp parser（LazyVim 默认名单里没有）
  -- 下次启动 mason 会自动去下载 clangd
  { import = "lazyvim.plugins.extras.lang.clangd" },

  -- 行内提示（参数名、auto 推出来的类型直接浮在代码里）
  -- LazyVim 默认关着；<leader>uh 可以随时开关
  {
    "neovim/nvim-lspconfig",
    opts = { inlay_hints = { enabled = true } },
  },
}