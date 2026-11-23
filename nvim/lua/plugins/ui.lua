return {
  -- 括号彩虹：C++ 那些三四层嵌套的括号按层上色，扫一眼就知道谁配谁
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = "LazyFile",
    config = function()
      require("rainbow-delimiters.setup").setup({})
    end,
  },

  -- 顶部标签栏精简：去掉关闭按钮和斜角，改成细线分隔 + 下划线指示
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        separator_style = "thin",
        show_buffer_close_icons = false,
        show_close_icon = false,
        indicator = { style = "underline" },
      },
    },
  },
}
