# Snacks.nvim Cheatsheet

A comprehensive guide to using snacks.nvim features in your Neovim setup.

## 🎯 Quick Reference

### Terminal Management

| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>tt` | Toggle Terminal | Open/close floating terminal |
| `<leader>tg` | Lazygit Terminal | Open lazygit in terminal |
| `<leader>tG` | GitUI Terminal | Open gitui in terminal |

**Usage Tips:**
- Terminal opens in a floating window (90% width/height)
- Press `<C-\><C-n>` to enter normal mode in terminal
- Use `:terminal <command>` for custom commands

---

### Scratch Buffers

| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>.` | Toggle Scratch | Open scratch buffer for quick notes |
| `<leader>S` | Select Scratch | Choose from saved scratch buffers |

**Features:**
- Auto-saves to `~/.local/share/nvim/scratch/`
- Defaults to markdown syntax
- Inherits filetype from current buffer if set
- Perfect for quick coding experiments or notes

---

### Notifications

| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>un` | Dismiss Notifications | Hide all current notifications |
| `<leader>nh` | Notification History | View all past notifications |

**Notification Levels:**
- 🔴 Error
- 🟡 Warn
- 🔵 Info
- ⚪ Debug
- ⚪ Trace

**Features:**
- 3-second timeout (auto-dismiss)
- Sorted by level and time
- History preserved for review
- Compact style for minimal distraction

---

### Git Integration

| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>gb` | Git Blame Line | Show blame for current line |
| `<leader>gB` | Git Browse | Open current file/line in GitHub/GitLab |
| `<leader>gf` | Lazygit Log (File) | Show git log for current file |
| `<leader>gl` | Lazygit Log | Show full git log |

**Statuscolumn Features:**
- Git signs in the gutter (add/change/delete)
- Integrated with sign column
- Minimal, clean appearance

---

### Zen Mode & Focus

| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>z` | Toggle Zen Mode | Distraction-free writing (120 columns) |
| `<leader>Z` | Toggle Zoom | Maximize current window |

**Zen Mode Features:**
- Dims inactive windows
- Hides statusline and tabline
- Disables diagnostics and git signs
- Perfect for writing documentation or focusing on code

**Zoom Mode:**
- Maximizes current split
- Keeps statusline and diagnostics
- Quick toggle to focus on one file

---

### Word Highlighting & Navigation

| Keybinding | Action | Description |
|------------|--------|-------------|
| `]]` | Next Reference | Jump to next occurrence of word under cursor |
| `[[` | Previous Reference | Jump to previous occurrence |

**Features:**
- Auto-highlights all occurrences of word under cursor
- 200ms debounce to avoid flickering
- Works in normal mode
- Opens folds automatically
- Adds to jumplist for `<C-o>/<C-i>` navigation

---

### Buffer Management

| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>bd` | Delete Buffer | Close current buffer intelligently |
| `<leader>bD` | Delete Other Buffers | Close all buffers except current |

**Features:**
- Smart deletion (preserves window layout)
- Won't close last window
- Handles modified buffers gracefully

---

### LSP & Code Actions

| Keybinding | Action | Description |
|------------|--------|-------------|
| `<leader>rn` | Rename File | Rename current file with LSP updates |

**Features:**
- Updates all references across project
- Shows preview of changes
- Notifies on completion
- Works with Elixir LSP (ElixirLS)

---

### Toggle Options

All toggles use `<leader>u` prefix and show notifications.

| Keybinding | Toggle | Description |
|------------|--------|-------------|
| `<leader>us` | Spelling | Enable/disable spell check |
| `<leader>uw` | Wrap | Toggle line wrapping |
| `<leader>uL` | Relative Numbers | Toggle relative line numbers |
| `<leader>ul` | Line Numbers | Toggle line numbers completely |
| `<leader>ud` | Diagnostics | Show/hide LSP diagnostics |
| `<leader>uc` | Conceal Level | Toggle concealment (markdown, etc.) |
| `<leader>uT` | Treesitter | Enable/disable treesitter |
| `<leader>ub` | Background | Toggle dark/light background |
| `<leader>uh` | Inlay Hints | Show/hide LSP inlay hints |
| `<leader>ug` | Indent Guides | Show/hide indent guides |
| `<leader>uD` | Dim Inactive | Dim inactive windows |

---

## 🎨 UI Features

### Dashboard

**Startup Screen:**
- Shows BEAM CAMPUS ASCII art
- Quick action buttons:
  - `f` - Find file
  - `n` - New file
  - `r` - Recent files
  - `g` - Find text (grep)
  - `c` - Open config
  - `s` - Restore session
  - `l` - Open Lazy (plugin manager)
  - `q` - Quit
- Displays startup time

### Statuscolumn

**Left Side:**
- Mark indicators
- Sign column (diagnostics, breakpoints)

**Right Side:**
- Fold indicators
- Git change indicators

**Features:**
- Minimal, clean design
- Automatic refresh (50ms)
- Git integration
- Fold opening on click

### Indent Guides

**Features:**
- Vertical lines showing indentation levels
- Highlighted current scope
- Character: `│`
- Scope highlighting for current block
- Works with Treesitter for semantic awareness

---

## 🚀 Performance Features

### Bigfile Handling

**Automatic Optimizations:**
- Triggers for files > 1.5MB
- Disables heavy features:
  - Syntax highlighting (uses basic)
  - Matchparen
  - Other performance-heavy plugins
- Shows notification when optimizations applied

### Quickfile

**Features:**
- Faster file opening
- Pre-loads frequently accessed files
- Automatic optimization
- Transparent to user

### Smooth Scrolling

**Features:**
- Linear easing
- 250ms total duration
- 15ms step duration
- Spam protection (max 10 scroll events)
- Enhances `<C-d>`, `<C-u>`, `<C-f>`, `<C-b>`

---

## 🛠️ Development Utilities

### Debug Helpers

**Global Functions:**
```lua
-- Inspect any Lua value
dd(some_variable)

-- Print backtrace
bt()

-- Enhanced print (uses dd)
print(value)
```

**Features:**
- Pretty-printed output
- Nested table inspection
- Automatic notification
- Useful for plugin development

---

## 🎯 Workflow Integration

### Elixir Development

**Optimized for:**
- Phoenix projects (use `<leader>tt` for IEx sessions)
- Mix tasks in terminal
- ExUnit tests
- Git blame for collaborative work
- Scratch buffers for REPL experiments

**Recommended Workflow:**
1. Use `<leader>tt` to open terminal for `iex -S mix phx.server`
2. Use `<leader>.` for quick Elixir code experiments
3. Use `<leader>gb` to check who wrote code
4. Use `<leader>z` when writing documentation
5. Use `]]`/`[[` to navigate between function references

### Git Workflow

**Best Practices:**
1. Use `<leader>tg` for visual git operations (lazygit)
2. Use `<leader>gb` for quick blame checks
3. Use `<leader>gB` to open files in GitHub
4. Check statuscolumn for quick diff indicators

### Writing & Documentation

**Optimized for:**
1. Toggle `<leader>z` for distraction-free writing
2. Enable `<leader>us` for spell check
3. Use `<leader>uw` for line wrapping
4. Use scratch buffers for draft work

---

## ⚙️ Configuration Tips

### Terminal Customization

Add custom terminal commands to keybindings:
```lua
-- Example: Elixir IEx
vim.keymap.set("n", "<leader>te", function()
  Snacks.terminal("iex -S mix")
end, { desc = "Elixir IEx" })
```

### Scratch Buffer Customization

Set default filetype for scratch:
```lua
-- In your snacks config
scratch = {
  ft = "elixir",  -- Always use Elixir syntax
}
```

### Notification Customization

Adjust timeout:
```lua
notifier = {
  timeout = 5000,  -- 5 seconds instead of 3
}
```

---

## 🔧 Troubleshooting

### Terminal not opening?
- Check that your terminal emulator supports floating windows
- Try `:checkhealth snacks`

### Git features not working?
- Ensure you're in a git repository
- Check that git is installed: `:!git --version`

### Scratch buffers not saving?
- Check permissions on `~/.local/share/nvim/scratch/`
- Verify `autowrite = true` in config

### Smooth scrolling too slow/fast?
- Adjust `duration.total` (lower = faster)
- Adjust `duration.step` (lower = smoother)

---

## 📚 Advanced Usage

### Custom Toggles

Create your own toggles:
```lua
-- Toggle autopairs
Snacks.toggle.option("autopairs", {
  name = "Auto Pairs",
  get = function() return vim.g.autopairs_enabled end,
  set = function(state) vim.g.autopairs_enabled = state end,
}):map("<leader>ua")
```

### Custom Notifications

Send custom notifications:
```lua
Snacks.notifier.notify("Build completed!", {
  level = "info",
  title = "Phoenix",
  icon = "󰡖",
})
```

### Custom Terminal Commands

Create project-specific terminals:
```lua
-- Phoenix server
vim.keymap.set("n", "<leader>tp", function()
  Snacks.terminal("mix phx.server", {
    cwd = vim.fn.getcwd(),
    env = { MIX_ENV = "dev" },
  })
end, { desc = "Phoenix Server" })
```

---

## 🎓 Learning Resources

### Essential Commands to Practice

1. **Start here:**
   - `<leader>tt` - Terminal
   - `<leader>.` - Scratch
   - `<leader>z` - Zen mode

2. **Git workflow:**
   - `<leader>tg` - Lazygit
   - `<leader>gb` - Blame

3. **Navigation:**
   - `]]` / `[[` - Word references
   - `<leader>bd` - Buffer delete

4. **Toggles:**
   - `<leader>us` - Spelling
   - `<leader>ul` - Line numbers
   - `<leader>uw` - Wrap

### Daily Workflow Example

```
1. Open Neovim → See dashboard
2. Press 'f' → Find file to work on
3. <leader>tt → Open terminal for tests
4. Edit code, use ]] to jump between references
5. <leader>gb → Check git blame
6. <leader>z → Enter zen mode for focus
7. <leader>. → Quick scratch for notes
8. <leader>tg → Commit with lazygit
9. :wq → Done!
```

---

## 🎁 Bonus Tips

1. **Combine with existing LazyVim features** - Snacks complements Telescope, LSP, and other plugins
2. **Muscle memory** - Practice one feature at a time
3. **Customize** - Adjust timeouts and keybindings to your preference
4. **Explore** - Run `:Snacks` to see all available commands
5. **Help** - Use `:help snacks.nvim` for detailed documentation

---

**Remember:** Snacks is designed to be intuitive. Most features work automatically in the background. Focus on learning the keybindings for the features you'll use most!

Happy coding! 🚀
