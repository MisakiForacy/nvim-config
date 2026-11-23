# quickrun.nvim ⚡

适用于算法竞赛的 Neovim 快速编译运行插件。三个命令搞定一切。

## 安装

### lazy.nvim

```lua
{
  "MisakiForacy/quickrun.nvim",
  opts = {},
  keys = {
    { "<leader>cc", "<cmd>Compile<cr>", desc = "编译" },
    { "<leader>cr", "<cmd>Crun<cr>",    desc = "编译并运行" },
    { "<leader>cR", "<cmd>Run<cr>",     desc = "运行" },
  },
}
```

### packer.nvim

```lua
use {
  "MisakiForacy/quickrun.nvim",
  config = function()
    require("quickrun").setup()
  end,
}
```

## 命令

| 命令 | 说明 |
|---|---|
| `:Compile` | 仅编译当前文件 |
| `:Crun` | 编译并运行（**最常用**） |
| `:Run` | 仅运行，跳过编译 |

## 支持的语言

| 语言 | 编译 | 运行 |
|---|---|---|
| **C++** | `g++ -std=c++20 -O2 -Wall -Wextra -Wshadow` | 直接执行 |
| **C** | `gcc -std=c11 -O2 -Wall -Wextra` | 直接执行 |
| **Python** | — | `python` |
| **Java** | `javac` | `java` |
| **Rust** | `rustc -O` | 直接执行 |
| **Go** | — | `go run` |
| **Lua** | — | `lua` |
| **JavaScript** | — | `node` |
| **TypeScript** | — | `npx ts-node` |

## 使用方式

在任意源代码文件中：

```
:Crun      " 编译 + 运行，终端从下方弹出，可直接输入 stdin
:Compile   " 只编译不运行，检查编译错误
:Run       " 只运行（已编译过，不想重新编译时用）
```

### 终端窗口操作

| 按键 | 模式 | 作用 |
|---|---|---|
| `q` | 普通模式 | 关闭终端 |
| `Ctrl-q` | 终端模式 | 关闭终端 |

## 配置

```lua
require("quickrun").setup({
  -- 终端位置: "below" | "above" | "tab" | "float"
  term_position = "below",

  -- 终端高度（行数），float 模式为窗口高度百分比
  term_height = 14,

  -- 运行成功后自动关闭终端
  auto_close = false,

  -- 自定义语言命令
  languages = {
    cpp = {
      -- 自定义编译选项
      compile = "g++ -std=c++23 -O2 -Wall -o {output} {source}",
      -- 自定义运行命令
      run = '"{output}"',
      -- 关联的文件扩展名
      ext = { "cpp", "cc", "cxx" },
      -- 输出文件扩展名 (Windows: .exe, Linux/macOS: "")
      output_ext = ".exe",
    },
  },
})
```

### 占位符

| 占位符 | 含义 | 示例 |
|---|---|---|
| `{source}` | 源文件绝对路径 | `/home/user/main.cpp` |
| `{output}` | 编译产物路径（同目录，无源扩展名） | `/home/user/main.exe` |
| `{classname}` | 文件名（无扩展名，用于 Java） | `Main` |

## 许可证

MIT
