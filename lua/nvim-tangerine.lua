-- File: ~/.config/nvim/lua/nvim-tangerine.lua
-- nvim-tangerine: A simple Neovim plugin for inline code auto‐completion using Ollama.
--
-- This plugin waits for 4 seconds of inactivity in Insert mode before sending
-- your code context to an Ollama endpoint. When a suggestion is returned,
-- it is displayed as ghost text (using virtual text) right after the cursor.
-- You can accept the suggestion by pressing Ctrl+Shift+Tab, which will insert only
-- the missing text.
--
-- Only one notification ("tangerine activated..") will be shown when a response is received.

local M = {}

local timer = vim.loop.new_timer()

-- Flag to prevent immediate subsequent server calls after a completion is accepted.
M.ignore_autocomplete_request = false

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
          -- Uncomment the next line for debugging:
          -- print("nvim-tangerine error (stderr): " .. vim.inspect(data))
        end)
      end
    end,
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        if exit_code ~= 0 then
          return
        end

        -- Notification when a response is received from Ollama
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
        suggestion = suggestion:gsub("`", "")
        if suggestion == "" then
          return
        end

        local missing, start_col = compute_missing_text(suggestion)
        if missing == "" then
          return
        end

        -- Clear any previous suggestion virtual text
        if M.current_suggestion then
          vim.api.nvim_buf_del_extmark(0, ns, M.current_suggestion.extmark_id)
          M.current_suggestion = nil
        end

        -- Set ghost text (virtual text) at the current cursor position.
        -- (Note: vim.api.nvim_win_get_cursor returns {row, col} where row is 1-indexed and col is 0-indexed.)
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row = cursor[1] - 1
        local col = cursor[2]
        local extmark_id = vim.api.nvim_buf_set_extmark(0, ns, row, col, {
          virt_text = { { missing, "Comment" } },
          virt_text_pos = "overlay",
        })
        M.current_suggestion = { extmark_id = extmark_id, missing = missing }
      end)
    end,
  })
end

--------------------------------------------------------------------------------
-- on_text_change is triggered on TextChangedI.
--------------------------------------------------------------------------------
local function on_text_change()
  if M.ignore_autocomplete_request then
    return
  end
  -- Clear any existing ghost text when the text changes.
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
  -- Remove the ghost text.
  vim.api.nvim_buf_del_extmark(0, ns, M.current_suggestion.extmark_id)
  M.current_suggestion = nil

  -- Schedule the insertion of the suggestion text.
  vim.schedule(function()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local new_line = line:sub(1, col) .. suggestion .. line:sub(col + 1)
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, { row, col + #suggestion })
  end)

  -- Prevent immediate subsequent server calls.
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
-- Setup autocommands and key mappings.
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

  -- Map Ctrl+Shift+Tab in Insert mode to accept our ghost suggestion if one exists.
  vim.keymap.set("i", "<C-S-Tab>", function()
    return M.ctrl_shift_tab_complete()
  end, { expr = true, noremap = true, silent = true })
end

return M
