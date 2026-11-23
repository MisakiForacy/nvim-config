-- 编译运行插件（随包自带，不依赖本机开发目录）
local root = vim.fn.stdpath("config")

return {
  {
    dir = root .. "/local/quickrun.nvim",
    lazy = false, -- 启动即加载，确保 :Compile / :Crun / :Run 始终可用
    config = function(_, opts)
      require("quickrun").setup(opts)
    end,
    keys = {
      { "<leader>cc", "<cmd>Compile<cr>", desc = "编译" },
      { "<leader>cr", "<cmd>Crun<cr>",    desc = "编译并运行" },
      { "<leader>cR", "<cmd>Run<cr>",     desc = "运行" },
    },
  },
}
