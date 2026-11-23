-- 音乐插件（随包自带，不依赖 GitHub，也不依赖本机的开发目录）
-- 音频守护进程用包里预编译的 exe；其他平台见 README 里 cargo build 的说明
local root = vim.fn.stdpath("config")

return {
  {
    dir = root .. "/local/musicode",
    name = "musicode",
    lazy = true,
    event = "VeryLazy", -- 别卡在启动主路径上
    config = function()
      require("musicode").setup({
        enabled = true,
        mode = "flow",
        sound = { backend = "rpc" },
        music = {
          -- 曲库放在 nvim 数据目录，跨机器通用
          library = vim.fn.stdpath("data") .. "/musicode/library",
          autostart = true,
          order = "shuffle",
        },
      })
    end,
  },
}
