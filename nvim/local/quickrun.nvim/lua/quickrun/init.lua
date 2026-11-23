-- quickrun.nvim — 算法竞赛快速编译运行插件
--
-- 命令:
--   :Compile  — 仅编译当前文件
--   :Crun     — 编译并运行（最常用）
--   :Run      — 仅运行（不编译）
--
-- 所有命令都在源文件所在目录执行，程序可正常读取相对路径的输入文件。
--
-- 安装 (lazy.nvim):
--   { "MisakiForacy/quickrun.nvim", opts = {} }
--

local M = {}

local default_config = {
  -- 终端位置: "below" | "above" | "tab" | "float"
  term_position = "below",
  -- 终端高度（行数）；float 模式时为窗口高度百分比
  term_height = 14,
  -- 运行成功后是否自动关闭终端
  auto_close = false,
  -- 各语言配置
  -- 命令在源文件所在目录执行，占位符仅使用文件名（不含路径）
  -- {source}=源文件名  {output}=可执行文件名  {classname}=类名
  languages = {
    cpp = {
      compile = "g++ -std=c++20 -O2 -Wall -Wextra -Wshadow -o {output} {source}",
      run = '"{output}"',
      ext = { "cpp", "cc", "cxx", "c++" },
      output_ext = ".exe",
    },
    c = {
      compile = "gcc -std=c11 -O2 -Wall -Wextra -o {output} {source}",
      run = '"{output}"',
      ext = { "c" },
      output_ext = ".exe",
    },
    python = {
      compile = nil,
      run = 'python "{source}"',
      ext = { "py", "py3", "pyw" },
    },
    java = {
      compile = "javac {source}",
      run = "java {classname}",
      ext = { "java" },
    },
    rust = {
      compile = "rustc -O {source} -o {output}",
      run = '"{output}"',
      ext = { "rs" },
      output_ext = ".exe",
    },
    go = {
      compile = nil,
      run = "go run {source}",
      ext = { "go" },
    },
    lua = {
      compile = nil,
      run = 'lua "{source}"',
      ext = { "lua" },
    },
    javascript = {
      compile = nil,
      run = "node {source}",
      ext = { "js", "mjs" },
    },
    typescript = {
      compile = nil,
      run = "npx ts-node {source}",
      ext = { "ts" },
    },
  },
}

local config = vim.deepcopy(default_config)

-- ── 工具函数 ──────────────────────────────────────────────────

---从文件扩展名检测语言
local function detect_language()
  local ext = vim.fn.expand("%:e"):lower()
  for lang, lang_conf in pairs(config.languages) do
    for _, e in ipairs(lang_conf.ext) do
      if e == ext then
        return lang, lang_conf
      end
    end
  end
  return nil, nil
end

---源文件所在目录（绝对路径）
local function get_dir()
  return vim.fn.expand("%:p:h")
end

---源文件名（不含路径）
local function get_source_name()
  return vim.fn.expand("%:t")
end

---编译输出文件名（不含路径，同目录下）
local function get_output_name(lang_conf)
  local basename = vim.fn.expand("%:t:r")
  local ext = lang_conf.output_ext or ""
  return basename .. ext
end

---替换命令模板占位符（全部使用文件名，不含路径）
local function build_cmd(template, lang_conf)
  return template
    :gsub("{source}", get_source_name())
    :gsub("{output}", get_output_name(lang_conf))
    :gsub("{classname}", vim.fn.expand("%:t:r"))
end

---打开终端，cd 到源文件目录后执行命令
---@param cmd string  要执行的命令
---@param title string  终端标题
---@param cwd string  工作目录（源文件所在目录）
local function open_terminal(cmd, title, cwd)
  local orig_win = vim.api.nvim_get_current_win()

  -- 创建终端窗口
  local pos = config.term_position
  if pos == "float" then
    local width = math.floor(vim.o.columns * 0.85)
    local height = math.floor(vim.o.lines * (config.term_height / 100))
    if height < 10 then height = 10 end
    local row = math.floor((vim.o.lines - height) / 2 - 2)
    local col = math.floor((vim.o.columns - width) / 2)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width, height = height,
      row = row, col = col,
      style = "minimal",
      border = "rounded",
      title = " " .. title .. " ",
      title_pos = "center",
    })
  elseif pos == "tab" then
    vim.cmd.tabnew()
  elseif pos == "above" then
    vim.cmd("aboveleft " .. config.term_height .. "split new")
  else
    vim.cmd("belowright " .. config.term_height .. "split new")
  end

  local term_buf = vim.api.nvim_get_current_buf()
  vim.bo[term_buf].bufhidden = "wipe"

  -- Windows: cd /d 可以切换盘符；Unix: cd 即可
  local cd_cmd = (vim.fn.has("win32") == 1)
      and ('cd /d "%s"'):format(cwd)
      or  ('cd "%s"'):format(cwd)

  -- 先 cd 到目录，再执行编译/运行命令
  local full_cmd = cd_cmd .. " && " .. cmd

  local job_id = vim.fn.termopen(full_cmd, {
    cwd = cwd, -- Neovim 0.7+ 支持，双重保险
    on_exit = function(_, code)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(term_buf) then return end
        if code == 0 then
          vim.notify("✓ " .. title .. " — 成功", vim.log.levels.INFO, { title = "QuickRun" })
          if config.auto_close then
            pcall(vim.api.nvim_buf_delete, term_buf, { force = true })
            pcall(vim.api.nvim_set_current_win, orig_win)
          end
        else
          vim.notify("✗ " .. title .. " — 退出码 " .. code, vim.log.levels.ERROR, { title = "QuickRun" })
        end
      end)
    end,
  })

  -- 进入插入模式，方便直接输入 stdin
  vim.cmd.startinsert()

  -- 关闭终端快捷键
  local function close()
    if vim.api.nvim_buf_is_valid(term_buf) then
      pcall(vim.api.nvim_buf_delete, term_buf, { force = true })
      pcall(vim.api.nvim_set_current_win, orig_win)
    end
  end
  vim.keymap.set("n", "q", close,   { buffer = term_buf, nowait = true, silent = true, desc = "关闭运行窗口" })
  vim.keymap.set("t", "<C-q>", close, { buffer = term_buf, nowait = true, silent = true, desc = "关闭运行窗口" })

  return term_buf, job_id
end

-- ── 命令 ──────────────────────────────────────────────────────

---:Compile — 仅编译
function M.compile()
  local lang, lang_conf = detect_language()
  if not lang then
    vim.notify("不支持的文件类型", vim.log.levels.ERROR, { title = "QuickRun" })
    return
  end
  if not lang_conf.compile then
    vim.notify(lang .. " 无需编译，请直接 :Run", vim.log.levels.WARN, { title = "QuickRun" })
    return
  end
  local cmd = build_cmd(lang_conf.compile, lang_conf)
  open_terminal(cmd, "Compile: " .. get_source_name(), get_dir())
end

---:Run — 仅运行
function M.run()
  local lang, lang_conf = detect_language()
  if not lang then
    vim.notify("不支持的文件类型", vim.log.levels.ERROR, { title = "QuickRun" })
    return
  end
  local cmd = build_cmd(lang_conf.run, lang_conf)
  open_terminal(cmd, "Run: " .. get_source_name(), get_dir())
end

---:Crun — 编译并运行
function M.crun()
  local lang, lang_conf = detect_language()
  if not lang then
    vim.notify("不支持的文件类型", vim.log.levels.ERROR, { title = "QuickRun" })
    return
  end
  if lang_conf.compile then
    local compile_cmd = build_cmd(lang_conf.compile, lang_conf)
    local run_cmd = build_cmd(lang_conf.run, lang_conf)
    -- 用 && 链接：编译失败则不运行
    local cmd = compile_cmd .. " && echo. && echo --- Compile OK, running --- && echo. && " .. run_cmd
    open_terminal(cmd, "Crun: " .. get_source_name(), get_dir())
  else
    M.run()
  end
end

-- ── Setup ─────────────────────────────────────────────────────

---初始化 quickrun.nvim
---@param opts? table  用户配置（与默认配置深度合并）
function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})

  vim.api.nvim_create_user_command("Compile", M.compile, { desc = "编译当前文件" })
  vim.api.nvim_create_user_command("Crun",    M.crun,    { desc = "编译并运行当前文件" })
  vim.api.nvim_create_user_command("Run",     M.run,     { desc = "运行当前文件" })
end

return M
