-- File: ~/.config/nvim/lua/nvim-tangerine.lua
-- nvim-tangerine: A simple Neovim plugin for inline code auto‐completion using Ollama.
--
-- This plugin waits for 4 seconds of inactivity in Insert mode before sending
-- your code context to an Ollama endpoint. When a suggestion is returned,
-- it is displayed as ghost text (using virtual text) right after the cursor.
-- You can accept the suggestion by pressing Ctrl+Shift+Tab, which will insert only
-- the missing text.
--
-- Use the commands :TangerineAuto on and :TangerineAuto off to enable or disable
-- automatic requests to Ollama. By default, auto-completion is enabled.
--
-- The new command :TangerineDescribeFile sends your entire file to Ollama with a prompt
-- asking for a concise description. When a response is received, only the JSON field "response"
-- is extracted (if available) and then shown in a modal floating window so your current file remains untouched.

local M = {}

local timer = vim.loop.new_timer()

-- Flag to prevent immediate subsequent server calls after a completion is accepted.
M.ignore_autocomplete_request = false

-- Flag to control whether auto-completion requests are sent.
M.auto_enabled = true

-- Hold the current suggestion ghost (if any):
--   { extmark_id = number, missing = string }
M.current_suggestion = nil

-- Create (or get) our namespace for extmarks/virtual text.
local ns = vim.api.nvim_create_namespace("nvim-tangerine")

--------------------------------------------------------------------------------
-- Compute the missing text by finding the longest common prefix between what
-- is already typed (before the cursor) and the full suggested line.
-- Returns:
--   missing   - The text that should be appended.
--   start_col - The current cursor column (1-indexed).
--------------------------------------------------------------------------------
local function compute_missing_text(suggestion)
  local line = vim.api.nvim_get_current_line()
  local col = vim.fn.col('.') -- current cursor column (1-indexed)
  local typed_before = line:sub(1, col - 1)
  local common = ""
  local max = math.min(#typed_before, #suggestion)
  for i = 1, max do
    local sub_typed = typed_before:sub(1, i)
    local sub_suggest = suggestion:sub(1, i)
    if sub_typed == sub_suggest then
      common = sub_typed
    else
      break
    end
  end
  local missing = suggestion:sub(#common + 1)
  return missing, col
end

--------------------------------------------------------------------------------
-- Request a code completion from the Ollama endpoint.
--------------------------------------------------------------------------------
local function request_completion()
  local buf = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local context = table.concat(lines, "\n")

  local prompt = string.format(
    "Complete the current line of %s code at cursor position %d:%d. " ..
    "Understand the whole code and give a valid code completion. " ..
    "Return ONLY the missing text to append to the current line. " ..
    "Do not provide multiple options, any commentary, or additional formatting. " ..
    "Do not enclose your code completion in any quotes or other delimiters. " ..
    "Output nothing but the exact code snippet.\n\n%s",
    filetype, cursor[1], cursor[2], context
  )

  local payload = vim.fn.json_encode({
    model = "deepseek-coder:6.7b",
    prompt = prompt,
    stream = false,
  })

  local cmd = {
    "curl",
    "-s",
    "-X", "POST",
    "http://localhost:11434/api/generate",
    "-H", "Content-Type: application/json",
    "-d", payload,
  }

  local output_lines = {}

  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      if data and not vim.tbl_isempty(data) then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            table.insert(output_lines, line)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data and not vim.tbl_isempty(data) then
        vim.schedule(function()
          -- Uncomment for debugging:
          -- print("nvim-tangerine error (stderr): " .. vim.inspect(data))
        end)
      end
    end,
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        if exit_code ~= 0 then
          return
        end

        vim.notify("tangerine activated..", vim.log.levels.INFO)

        local raw_response = table.concat(output_lines, "\n")
        raw_response = raw_response:gsub("^%s+", ""):gsub("%s+$", "")
        if raw_response == "" then
          return
        end

        local suggestion = raw_response
        if raw_response:sub(1, 1) == "{" then
          local ok, decoded = pcall(vim.fn.json_decode, raw_response)
          if ok and type(decoded) == "table" and decoded.response and decoded.response ~= "" then
            suggestion = decoded.response
          else
            suggestion = raw_response
          end
        end

        suggestion = suggestion:gsub("^%d+%.%s*", "")
        suggestion = suggestion:gsub("^%s+", ""):gsub("%s+$", "")
        if suggestion == "" then
          return
        end

        if M.current_suggestion then
          vim.api.nvim_buf_del_extmark(0, ns, M.current_suggestion.extmark_id)
          M.current_suggestion = nil
        end

        -- Set ghost text (virtual text) at the current cursor position.
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row = cursor[1] - 1
        local col = cursor[2]
        local extmark_id = vim.api.nvim_buf_set_extmark(0, ns, row, col, {
          virt_text = { { suggestion, "Comment" } },
          virt_text_pos = "overlay",
        })
        M.current_suggestion = { extmark_id = extmark_id, missing = suggestion }
      end)
    end,
  })
end

--------------------------------------------------------------------------------
-- on_text_change is triggered on TextChangedI.
-- It now respects the auto_enabled flag and activates only for file buffers.
--------------------------------------------------------------------------------
local function on_text_change()
  local buf = vim.api.nvim_get_current_buf()

  if vim.api.nvim_buf_get_option(buf, "buftype") ~= "" then
    return
  end

  local disallowed_filetypes = {
    TelescopePrompt = true,
    NvimTree = true,
    dashboard = true,
    fzf = true,
    ["neo-tree"] = true,
    quickfix = true,
  }
  local ft = vim.api.nvim_buf_get_option(buf, "filetype")
  if disallowed_filetypes[ft] then
    return
  end

  if M.ignore_autocomplete_request or not M.auto_enabled then
    return
  end

  if M.current_suggestion then
    vim.api.nvim_buf_del_extmark(0, ns, M.current_suggestion.extmark_id)
    M.current_suggestion = nil
  end

  timer:stop()
  timer:start(4000, 0, vim.schedule_wrap(function()
    request_completion()
  end))
end

--------------------------------------------------------------------------------
-- Accept the current ghost suggestion (if any) and insert its text.
-- The text change is scheduled to avoid synchronous modifications.
--------------------------------------------------------------------------------
function M.accept_suggestion()
  if not M.current_suggestion then
    return vim.api.nvim_replace_termcodes("<C-S-Tab>", true, true, true)
  end

  local suggestion = M.current_suggestion.missing
  vim.api.nvim_buf_del_extmark(0, ns, M.current_suggestion.extmark_id)
  M.current_suggestion = nil

  vim.schedule(function()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local new_line = line:sub(1, col) .. suggestion .. line:sub(col + 1)
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, { row, col + #suggestion })
  end)

  M.ignore_autocomplete_request = true
  vim.defer_fn(function()
    M.ignore_autocomplete_request = false
  end, 1000)

  return ""
end

--------------------------------------------------------------------------------
-- This function is used in the Ctrl+Shift+Tab mapping.
-- If a suggestion is active, it is accepted; otherwise, the key sequence is passed through.
--------------------------------------------------------------------------------
function M.ctrl_shift_tab_complete()
  if M.current_suggestion then
    return M.accept_suggestion()
  else
    return vim.api.nvim_replace_termcodes("<C-S-Tab>", true, true, true)
  end
end

--------------------------------------------------------------------------------
-- Enable auto-completion requests.
--------------------------------------------------------------------------------
function M.auto_on()
  M.auto_enabled = true
  vim.notify("Tangerine auto completion enabled", vim.log.levels.INFO)
end

--------------------------------------------------------------------------------
-- Disable auto-completion requests.
--------------------------------------------------------------------------------
function M.auto_off()
  M.auto_enabled = false
  vim.notify("Tangerine auto completion disabled", vim.log.levels.INFO)
end

--------------------------------------------------------------------------------
-- Clear any existing ghost suggestion.
--------------------------------------------------------------------------------
function M.clear_suggestion()
  if M.current_suggestion then
    vim.api.nvim_buf_del_extmark(0, ns, M.current_suggestion.extmark_id)
    M.current_suggestion = nil
  end
end

--------------------------------------------------------------------------------
-- Helper: Open a modal floating window with padded header and ESC [x] indicator.
--------------------------------------------------------------------------------
local function open_floating_window(content)
  local width = math.floor(vim.o.columns * 0.5)
  local height = math.floor(vim.o.lines * 0.5)
  -- Build header with padding.
  local header = "Tangerine code summary of this file"
  local close_text = "[x] esc"
  local header_len = #header
  local close_len = #close_text
  local total_padding = width - 4 - header_len - close_len  -- 4 extra spaces for left/right padding
  if total_padding < 1 then total_padding = 1 end
  local spaces = string.rep(" ", total_padding)
  local header_line = "  " .. header .. spaces .. close_text

  -- Build modal content with header and padding.
  local lines = {}
  table.insert(lines, header_line)
  table.insert(lines, "") -- padding after header
  for _, line in ipairs(vim.split(content, "\n")) do
    table.insert(lines, "  " .. line)
  end
  table.insert(lines, "") -- bottom padding

  local buf = vim.api.nvim_create_buf(false, true)  -- create scratch buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  }
  local win = vim.api.nvim_open_win(buf, true, opts)
  -- Map <Esc> in normal mode for this buffer to close the window.
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<CR>", { noremap = true, silent = true })
end

--------------------------------------------------------------------------------
-- Describe the current file.
--
-- This function sends the entire file content along with a prompt to Ollama,
-- asking for a concise description of the file’s functionality, purpose, and notable features.
-- It then processes the response exactly like the autocomplete function:
-- if the raw response begins with a "{", it attempts to decode JSON and, if successful,
-- uses the "response" field; otherwise it falls back to the raw response.
-- Finally, the description is displayed in a modal floating window.
-- An extra cleaning step removes lines that consist only of digits, commas, and spaces.
-- Also, only the JSON block (balanced curly braces) is extracted for decoding.
--------------------------------------------------------------------------------
function M.describe_file()
  local buf = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local context = table.concat(lines, "\n")

  vim.notify("Tangerine is analysing....", vim.log.levels.INFO)

  local prompt = string.format(
    "You are a code analysis assistant. Analyze the following %s file and provide a concise, clear description of its functionality, purpose, and notable features. " ..
    "Do not include any code snippets, commentary, or extraneous text; provide only the description.\n\n%s",
    filetype, context
  )

  local payload = vim.fn.json_encode({
    model = "deepseek-coder:6.7b",
    prompt = prompt,
    stream = false,
  })

  local cmd = {
    "curl",
    "-s",
    "-X", "POST",
    "http://localhost:11434/api/generate",
    "-H", "Content-Type: application/json",
    "-d", payload,
  }

  local output_lines = {}

  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      if data and not vim.tbl_isempty(data) then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            table.insert(output_lines, line)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data and not vim.tbl_isempty(data) then
        vim.schedule(function()
          -- Uncomment for debugging:
          -- print("nvim-tangerine describe error (stderr): " .. vim.inspect(data))
        end)
      end
    end,
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        if exit_code ~= 0 then
          vim.notify("Error generating file description", vim.log.levels.ERROR)
          return
        end

        local raw_response = table.concat(output_lines, "\n")
        raw_response = raw_response:gsub("^%s+", ""):gsub("%s+$", "")
        if raw_response == "" then
          vim.notify("No description received", vim.log.levels.WARN)
          return
        end

        -- Try decoding the entire response as JSON.
        local ok, decoded = pcall(vim.fn.json_decode, raw_response)
        local description = raw_response
        if ok and type(decoded) == "table" and decoded.response and decoded.response ~= "" then
          description = decoded.response
        else
          -- If decoding fails, try extracting a JSON block.
          local json_text = raw_response:match("^(%b{})")
          if json_text then
            ok, decoded = pcall(vim.fn.json_decode, json_text)
            if ok and type(decoded) == "table" and decoded.response and decoded.response ~= "" then
              description = decoded.response
            end
          end
        end

        description = description:gsub("^%d+%.%s*", "")
        description = description:gsub("^%s+", ""):gsub("%s+$", "")

        -- Remove lines that consist solely of digits, commas, and whitespace.
        local cleaned_lines = {}
        for _, line in ipairs(vim.split(description, "\n")) do
          if not line:match("^%s*[%d,%s]+%s*$") then
            table.insert(cleaned_lines, line)
          end
        end
        description = table.concat(cleaned_lines, "\n")
        if description == "" then
          return
        end

        open_floating_window(description)
        vim.notify("File description generated", vim.log.levels.INFO)
      end)
    end,
  })
end

--------------------------------------------------------------------------------
-- Setup autocommands, key mappings, and user commands.
--------------------------------------------------------------------------------
function M.setup()
  vim.api.nvim_create_autocmd("TextChangedI", {
    pattern = "*",
    callback = on_text_change,
    desc = "Trigger nvim-tangerine code completion after 4 seconds of inactivity",
  })

  vim.api.nvim_create_autocmd("CompleteDone", {
    pattern = "*",
    callback = function()
      M.ignore_autocomplete_request = true
      vim.defer_fn(function()
        M.ignore_autocomplete_request = false
      end, 1000)
    end,
    desc = "Ignore server request immediately after completion",
  })

  vim.api.nvim_create_autocmd("CursorMovedI", {
    pattern = "*",
    callback = function()
      if M.current_suggestion then
        vim.api.nvim_buf_del_extmark(0, ns, M.current_suggestion.extmark_id)
        M.current_suggestion = nil
      end
    end,
    desc = "Clear ghost suggestion when moving the cursor in Insert mode",
  })

  vim.keymap.set("i", "<C-S-Tab>", function()
    return M.ctrl_shift_tab_complete()
  end, { expr = true, noremap = true, silent = true })

  vim.api.nvim_create_user_command("TangerineAuto", function(opts)
    if opts.args == "on" then
      M.auto_on()
    elseif opts.args == "off" then
      M.auto_off()
    else
      vim.notify("Usage: :TangerineAuto [on|off]", vim.log.levels.ERROR)
    end
  end, { nargs = 1, complete = function() return {"on", "off"} end })

  vim.api.nvim_create_user_command("TangerineDescribeFile", function()
    M.describe_file()
  end, { nargs = 0 })
end

return M