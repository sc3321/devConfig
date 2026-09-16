-- =========================
-- Lean Neovim for C/C++ + Python (Nvim 0.11+)
-- =========================

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- =========================
-- Options
-- =========================
local o = vim.opt
o.number = true
o.relativenumber = true      -- makes counts like 12j / 7k readable at a glance
o.mouse = "a"
o.clipboard = "unnamedplus"  -- over SSH, Nvim falls back to OSC 52 (tmux: `set -g set-clipboard on`)
o.ignorecase = true
o.smartcase = true
o.expandtab = true
o.shiftwidth = 4             -- a repo .editorconfig (built-in support) overrides these
o.tabstop = 4
o.termguicolors = true
o.splitright = true
o.splitbelow = true
o.updatetime = 250
o.signcolumn = "yes"
o.scrolloff = 8              -- keep context visible after jumps
o.cursorline = true
o.undofile = true            -- undo history survives closing a file
o.inccommand = "split"       -- live preview for :s/old/new/

-- Diagnostics: 0.11 turned inline messages off by default; turn them back on
vim.diagnostic.config({
  virtual_text = true,
  severity_sort = true,
  float = { border = "rounded" },
})

-- =========================
-- Keymaps (only things Nvim doesn't already provide)
-- =========================
vim.keymap.set("i", "jk", "<Esc>")
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
vim.keymap.set("n", "<leader>q", "<cmd>bdelete<CR>", { desc = "Close buffer" })

-- Splits: <leader>h horizontal, <leader>v vertical
vim.keymap.set("n", "<leader>h", "<cmd>split<CR>", { desc = "Horizontal split" })
vim.keymap.set("n", "<leader>v", "<cmd>vsplit<CR>", { desc = "Vertical split" })

-- TRAINING BLOCK: arrows disabled in normal/visual mode.
-- Delete this block after ~3 weeks, once jumping is automatic.
for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
  vim.keymap.set({ "n", "v" }, key, function()
    vim.notify("Jump instead: 12j, /text, *, gd, <C-o>", vim.log.levels.WARN)
  end)
end

-- =========================
-- Bootstrap lazy.nvim
-- =========================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- =========================
-- Plugins
-- (lazy.nvim loads plugins at startup unless you give keys/cmd/event,
--  so `lazy = false` everywhere was redundant)
-- =========================
require("lazy").setup({
  spec = {

    -- Theme
    {
      "catppuccin/nvim",
      name = "catppuccin",
      priority = 1000,
      config = function()
        require("catppuccin").setup({ flavour = "macchiato" })
        vim.cmd.colorscheme("catppuccin-macchiato")
      end,
    },

    -- Ctrl-h/j/k/l moves between Nvim splits AND tmux panes seamlessly
    {
      "christoomey/vim-tmux-navigator",
      cmd = { "TmuxNavigateLeft", "TmuxNavigateDown", "TmuxNavigateUp", "TmuxNavigateRight" },
      keys = {
        { "<C-h>", "<cmd>TmuxNavigateLeft<CR>", desc = "Pane left" },
        { "<C-j>", "<cmd>TmuxNavigateDown<CR>", desc = "Pane down" },
        { "<C-k>", "<cmd>TmuxNavigateUp<CR>", desc = "Pane up" },
        { "<C-l>", "<cmd>TmuxNavigateRight<CR>", desc = "Pane right" },
      },
    },

    -- Statusline
    {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        local clock = function() return os.date("%a %d %b %H:%M") end
        require("lualine").setup({
          options = {
            theme = "auto",
            component_separators = { left = "|", right = "|" },
            section_separators = { left = "", right = "" },
            globalstatus = true,
          },
          sections = {
            lualine_a = { "mode" },
            lualine_b = { "branch", "diff", "diagnostics" },
            lualine_c = { { "filename", path = 1 } },
            lualine_x = { clock, "filetype" },
            lualine_y = { "progress" },
            lualine_z = { "location" },
          },
        })
      end,
    },

    -- Git change markers in the sign column (git repos only)
    {
      "lewis6991/gitsigns.nvim",
      opts = {
        on_attach = function(bufnr)
          local gs = require("gitsigns")
          local map = function(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
          end
          map("]h", function() gs.nav_hunk("next") end, "Next git hunk")
          map("[h", function() gs.nav_hunk("prev") end, "Prev git hunk")
          map("<leader>gp", gs.preview_hunk, "Preview hunk")
          map("<leader>gb", gs.blame_line, "Blame line")
        end,
      },
    },

    -- Shows pending keybindings after you press a prefix (e.g. <leader>)
    {
      "folke/which-key.nvim",
      opts = {
        spec = {
          { "<leader>f", group = "find" },
          { "<leader>l", group = "lsp" },
          { "<leader>g", group = "git" },
          { "<leader>e", group = "explorer" },
        },
      },
    },

    -- Auto-close brackets/quotes
    { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },

    -- File explorer (secondary tool; Telescope + LSP are primary in big repos)
    {
      "nvim-tree/nvim-tree.lua",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require("nvim-tree").setup({
          sync_root_with_cwd = true,
          view = { width = 32 },
        })
        vim.keymap.set("n", "<leader>ee", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle explorer" })
        vim.keymap.set("n", "<leader>ef", "<cmd>NvimTreeFindFile<CR>", { desc = "Reveal current file" })
      end,
    },

    -- Telescope: fuzzy finding for files, text, buffers, symbols
    {
      "nvim-telescope/telescope.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
        -- Native C sorter: noticeably faster on repos with huge file counts
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      },
      config = function()
        local telescope = require("telescope")
        telescope.setup({
          defaults = {
            path_display = { "truncate" }, -- deep paths: keep the filename end visible
          },
          pickers = {
            find_files = { theme = "dropdown" },
          },
        })
        pcall(telescope.load_extension, "fzf")

        local b = require("telescope.builtin")
        local map = function(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { desc = desc }) end
        map("<leader>ff", b.find_files, "Find files")
        map("<leader>fg", b.live_grep, "Grep project")
        map("<leader>fw", b.grep_string, "Grep word under cursor")
        map("<leader>fb", b.buffers, "Open buffers")
        map("<leader>fs", b.current_buffer_fuzzy_find, "Search in file")
        map("<leader>fr", b.resume, "Resume last search")
        map("<leader>fd", b.diagnostics, "Diagnostics")
      end,
    },

    -- Treesitter: syntax-tree based highlighting
    {
      "nvim-treesitter/nvim-treesitter",
      branch = "master", -- classic API used below; `main` is a rewrite with a different setup
      build = ":TSUpdate",
      config = function()
        require("nvim-treesitter.configs").setup({
          ensure_installed = { "c", "cpp", "python", "lua", "bash", "cmake", "make" },
          highlight = {
            enable = true,
            -- Generated files can be many MB; don't choke on them
            disable = function(_, buf)
              local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
              return ok and stats and stats.size > 1024 * 1024
            end,
          },
          -- Treesitter C/C++ indent is unreliable; built-in cindent does better
          indent = { enable = true, disable = { "c", "cpp" } },
        })
      end,
    },

    -- Installs language servers you can't get elsewhere (here: pyright).
    -- Run :MasonInstall pyright once. clangd comes from your system/LLVM.
    { "mason-org/mason.nvim", opts = {} },

    -- Supplies default server configs (cmd, filetypes, root markers) for vim.lsp.enable
    { "neovim/nvim-lspconfig" },

    -- Completion
    {
      "saghen/blink.cmp",
      version = "1.*",
      dependencies = { "rafamadriz/friendly-snippets" },
      opts = {
        keymap = { preset = "super-tab" },
        sources = { default = { "lsp", "path", "snippets", "buffer" } },
        signature = { enabled = true },
      },
    },
  },
})

-- =========================
-- LSP (Neovim 0.11 native)
-- =========================
vim.lsp.config("*", {
  capabilities = require("blink.cmp").get_lsp_capabilities(),
})

vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "--background-index",        -- index whole project for cross-file references
    "--header-insertion=never",  -- don't silently add #includes to code you don't own
    "--completion-style=detailed",
    "--pch-storage=memory",
    -- If the repo builds with a non-system GCC, point clangd at it so it finds
    -- the right standard library headers:
    -- "--query-driver=/path/to/toolchain/bin/g++*",
  },
})

vim.lsp.enable({ "clangd", "pyright" })

-- =========================
-- LSP keymaps (buffer-local, only when a server attaches)
--
-- Built-in defaults you should use instead of custom maps:
--   K      hover            grn  rename           gra  code action
--   grr    references       gri  implementation   gO   document symbols
--   [d ]d  prev/next diag   <C-w>d  diagnostic float
--   <C-]>  definition (LSP-backed), <C-t> to come back
-- =========================
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local b = require("telescope.builtin")
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    local map = function(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc })
    end

    map("gd", b.lsp_definitions, "Go to definition")
    map("gD", vim.lsp.buf.declaration, "Go to declaration")
    map("<leader>lr", b.lsp_references, "References (picker)")
    map("<leader>ls", b.lsp_document_symbols, "Symbols in file")
    map("<leader>lS", b.lsp_dynamic_workspace_symbols, "Symbols in project")
    map("<leader>lc", b.lsp_incoming_calls, "Who calls this?")

    if client and client.name == "clangd" then
      map("<leader>lo", "<cmd>LspClangdSwitchSourceHeader<CR>", "Switch header/source")
    end
  end,
})
