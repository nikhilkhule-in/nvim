vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Plugins 
vim.pack.add({
    { src = "https://github.com/nvim-lua/plenary.nvim" },
    { src = "https://github.com/lewis6991/gitsigns.nvim" },
    { src = "https://github.com/stevearc/conform.nvim" },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main", build = ":TSUpdate" },
    { src = "https://github.com/SmiteshP/nvim-navic" },
    { src = "https://github.com/benomahony/uv.nvim" },
    { src = "https://github.com/nvim-lualine/lualine.nvim" },
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/hrsh7th/nvim-cmp" },
    { src = "https://github.com/hrsh7th/cmp-nvim-lsp" },
    { src = "https://github.com/hrsh7th/cmp-buffer" },
    { src = "https://github.com/hrsh7th/cmp-path" },
    { src = "https://github.com/L3MON4D3/LuaSnip" },
    { src = "https://github.com/saadparwaiz1/cmp_luasnip" },
    { src = "https://github.com/MeanderingProgrammer/render-markdown.nvim" },
    { src = "https://github.com/folke/snacks.nvim" },
    { src = "https://github.com/mason-org/mason.nvim" },
    { src = "https://github.com/projekt0n/github-nvim-theme" },
    { src = "https://github.com/gmr458/vscode_modern_theme.nvim" },
    { src = "https://github.com/EdenEast/nightfox.nvim.git" },
})

-- snacks.nvim
local snacks_ok, snacks = pcall(require, "snacks")
if snacks_ok then
    snacks.setup({
        bigfile      = { enabled = true },
        notifier     = { enabled = true },
        indent       = { enabled = true },
        input        = { enabled = true },
        scroll       = { enabled = true },
        words        = { enabled = true },
        terminal     = { enabled = true },
        bufdelete    = { enabled = true },
        dashboard    = { 
            enabled = true,
            sections = {
                { section = "header" },
                { section = "keys", gap = 1, padding = 1 },
            },
        },
        picker       = { enabled = true, hidden = true },
        explorer     = { enabled = true },
        animate      = { enabled = true },
        statuscolumn = { enabled = true },
    })
end

-- Options 
local opt = vim.opt

-- Keymaps 
local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

opt.number         = true
opt.relativenumber = true
opt.signcolumn     = "yes"   -- always show; prevents layout shifts on diagnostics
opt.cursorline     = true
opt.guicursor      = ""
opt.mouse          = "a"
opt.termguicolors  = true
opt.scrolloff      = 8
opt.splitright     = true
opt.splitbelow     = true
opt.undofile       = true    -- persist undo history across sessions
opt.updatetime     = 250     -- faster CursorHold events (used by codelens, etc.)
opt.timeoutlen     = 300

-- Search
opt.ignorecase = true
opt.smartcase  = true        -- case-sensitive only when query has uppercase
opt.hlsearch   = true
opt.incsearch  = true

-- Indentation
opt.tabstop     = 4
opt.shiftwidth  = 4
opt.expandtab   = true
opt.smartindent = true

-- nvim-cmp handles completion

-- Diagnostics 
local sev = vim.diagnostic.severity

vim.diagnostic.config({
    severity_sort = true,
    float         = { border = "rounded" },
    virtual_text  = {
        severity = { min = sev.WARN }, -- only show warnings and above inline
    },
})

-- LSP 
vim.lsp.config("basedpyright", {
    cmd          = { "basedpyright-langserver", "--stdio" },
    filetypes    = { "python" },
    root_markers = { "pyproject.toml", "setup.py", "setup.cfg", ".git" },
    settings     = {
        basedpyright = { analysis = { typeCheckingMode = "standard", venvPath = ".", venv = ".venv" } },
    },
})

vim.lsp.config("gopls", {
    cmd          = { "gopls" },
    filetypes    = { "go", "gomod", "gowork" },
    root_markers = { "go.mod", "go.work", ".git" },
    settings     = {
        gopls = { gofumpt = true },
    },
})

vim.lsp.config("golangci_lint_ls", {
    cmd          = { "golangci-lint-langserver" },
    filetypes    = { "go", "gomod" },
    root_markers = { "go.mod", ".git" },
})

vim.lsp.config("lua_ls", {
    cmd          = { "lua-language-server" },
    filetypes    = { "lua" },
    root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
    settings     = {
        Lua = {
            runtime   = { version = "LuaJIT" },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
        },
    },
})

vim.lsp.config("ts_ls", {
    cmd          = { "typescript-language-server", "--stdio" },
    filetypes    = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
    settings     = {
        typescript = {
            inlayHints = {
                includeInlayParameterNameHints = "all",
                includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayEnumMemberValueHints = true,
            },
        },
    },
})

local mason_ok, mason = pcall(require, "mason")
local registry_ok, registry = pcall(require, "mason-registry")
if mason_ok and registry_ok then
    mason.setup()
    local prompted = {}
    local function servers_for_ft(ft)
        local servers = {}
        for name, config in pairs(vim.lsp.config) do
            if config.filetypes and vim.tbl_contains(config.filetypes, ft) then
                table.insert(servers, name)
            end
        end
        table.sort(servers)
        return servers
    end

    vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
            vim.schedule(function()
                local missing = {}

                for _, server in ipairs(servers_for_ft(args.match)) do
                    if not prompted[server] then
                        local ok, pkg = pcall(registry.get_package, server)

                        if ok and not pkg:is_installed() then
                            table.insert(missing, {
                                server = server,
                                package = pkg,
                            })
                        end
                    end
                end

                if #missing == 0 then
                    return
                end

                if #missing == 1 then
                    local item = missing[1]

                    vim.ui.select({ "Install", "Cancel" }, {
                        prompt = ("Install %s?"):format(item.server),
                    }, function(choice)
                        prompted[item.server] = true

                        if choice == "Install" then
                            item.package:install()
                        end
                    end)

                    return
                end

                if snacks_ok then
                    Snacks.picker.select(missing, {
                        prompt = "Select language server to install",
                        format_item = function(item)
                            return item.server
                        end,
                    }, function(item)
                        if item then
                            prompted[item.server] = true
                            item.package:install()
                        end
                    end)
                else
                    local names = vim.tbl_map(function(item)
                        return item.server
                    end, missing)

                    vim.ui.select(names, {
                        prompt = "Select language server to install",
                    }, function(choice)
                        if not choice then
                            return
                        end

                        for _, item in ipairs(missing) do
                            if item.server == choice then
                                prompted[item.server] = true
                                item.package:install()
                                break
                            end
                        end
                    end)
                end
            end)
        end,
    })
end

-- nvim-cmp capabilities for LSP
local cmp_capabilities = (function()
    local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
    return ok and cmp_lsp.default_capabilities() or vim.lsp.protocol.make_client_capabilities()
end)()
vim.lsp.config("*", { capabilities = cmp_capabilities })

-- tsgo (native TypeScript 7 Go LSP)
vim.lsp.config("tsgo", {
    cmd = { "tsgo", "--lsp", "--stdio" },

    filetypes = {
        "typescript",
        "javascript",
        "typescriptreact",
        "javascriptreact",
    },

    root_dir = vim.fs.root(0, {
        "tsconfig.json",
        "jsconfig.json",
        "package.json",
        ".git",
    }),

    settings = {
        typescript = {
            inlayHints = {
                parameterNames = { enabled = "literals" },
                parameterTypes = { enabled = true },
                variableTypes = { enabled = true },
                functionLikeReturnTypes = { enabled = true },
                enumMemberValues = { enabled = true },
            },
            preferences = {
                importModuleSpecifier = "non-relative",
            },
        },
        javascript = {
            inlayHints = {
                parameterNames = { enabled = "literals" },
                variableTypes = { enabled = true },
            },
        },
    },
})

vim.lsp.enable({ "basedpyright", "gopls", "golangci_lint_ls", "lua_ls", "tsgo" })

-- Enable inlay hints and code lens when the server supports them
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client then
            return
        end

        -- Inlay hints
        if client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
        end

        -- CodeLens
        if client:supports_method("textDocument/codeLens") then
            vim.lsp.codelens.enable(true, { bufnr = ev.buf })

            local codelens_group = vim.api.nvim_create_augroup(
                "lsp-codelens-" .. ev.buf,
                { clear = true }
            )

            vim.api.nvim_create_autocmd({
                "BufEnter",
                "BufWinEnter",
                "BufWritePost",
                "InsertLeave",
                "TextChanged",
                "TextChangedI",
                "CursorHold",
                "CursorHoldI",
                "FocusGained",
            }, {
                group = codelens_group,
                buffer = ev.buf,
                callback = function()
                    vim.lsp.codelens.enable(true, { bufnr = ev.buf })
                end,
            })
        end

        -- Symbol highlighting
        if client:supports_method("textDocument/documentHighlight") then
            local highlight_group = vim.api.nvim_create_augroup(
                "lsp-highlight-" .. ev.buf,
                { clear = true }
            )

            vim.api.nvim_create_autocmd(
                { "CursorHold", "CursorHoldI" },
                {
                    group = highlight_group,
                    buffer = ev.buf,
                    callback = vim.lsp.buf.document_highlight,
                }
            )

            vim.api.nvim_create_autocmd(
                { "CursorMoved", "CursorMovedI" },
                {
                    group = highlight_group,
                    buffer = ev.buf,
                    callback = vim.lsp.buf.clear_references,
                }
            )
        end

        -- Navic breadcrumbs
        local ok, navic = pcall(require, "nvim-navic")
        if ok
            and client:supports_method("textDocument/documentSymbol")
            then
                navic.attach(client, ev.buf)
            end
        end,
    })

-- nvim-cmp
local cmp_ok, cmp = pcall(require, "cmp")
if cmp_ok then
    local kind_icons = {
        Text          = "\u{f0d18}",
        Method        = "\u{f06b1}",
        Function      = "\u{f0530}",
        Constructor   = "\u{f0bd7}",
        Field         = "\u{f0ba9}",
        Variable      = "\u{f0628}",
        Class         = "\u{f0ec6}",
        Interface     = "\u{f0f8a}",
        Module        = "\u{f0480}",
        Property      = "\u{f032b}",
        Unit          = "\u{f0493}",
        Value         = "\u{f0556}",
        Enum          = "\u{f02ad}",
        Keyword       = "\u{f03fe}",
        Snippet       = "\u{f0cce}",
        Color         = "\u{f0f3c}",
        File          = "\u{f0168}",
        Reference     = "\u{f0318}",
        Folder        = "\u{f0169}",
        EnumMember    = "\u{f02ad}",
        Constant      = "\u{f04d9}",
        Struct        = "\u{f0ec6}",
        Event         = "\u{f01ad}",
        Operator      = "\u{f0599}",
        TypeParameter = "\u{f0cec}",
    }

    cmp.setup({
        snippet = {
            expand = function(args)
                require("luasnip").lsp_expand(args.body)
            end,
        },
        mapping = cmp.mapping.preset.insert({
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<CR>"] = cmp.mapping.confirm({ select = true }),
            ["<Tab>"] = cmp.mapping.select_next_item(),
            ["<S-Tab>"] = cmp.mapping.select_prev_item(),
        }),
        sources = cmp.config.sources({
            { name = "nvim_lsp" },
        }, {
            { name = "buffer" },
            { name = "path" },
        }),
        window = {
            completion = {
                border = "rounded",
                winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None",
            },
            documentation = {
                border = "rounded",
            },
        },
        formatting = {
            format = function(entry, vim_item)
                vim_item.kind = (kind_icons[vim_item.kind] or "") .. " " .. vim_item.kind
                return vim_item
            end,
        },
    })
end

-- Formatting
local cf_ok, conform = pcall(require, "conform")
if cf_ok then
    conform.setup({
        formatters_by_ft = {
            lua    = { "stylua" },
            python = { "ruff_format" },
            go     = { "gofmt" },
            javascript = { "prettierd", "prettier" },
            javascriptreact = { "prettierd", "prettier" },
            typescript = { "prettierd", "prettier" },
            typescriptreact = { "prettierd", "prettier" },
            json       = { "prettierd", "prettier" },
            yaml       = { "prettierd", "prettier" },
            markdown   = { "prettierd", "prettier" },
            c = {"astyle"},
        },
    })
    vim.api.nvim_create_autocmd("BufWritePre", {
        callback = function(args)
            conform.format({ bufnr = args.buf, lsp_fallback = true })
        end,
    })
    vim.api.nvim_create_autocmd("InsertLeave", {
        callback = function(args)
            if vim.bo[args.buf].filetype ~= "" then
                conform.format({ bufnr = args.buf, lsp_fallback = true })
            end
        end,
    })
    map("v", "<leader>lf", function()
        conform.format({ range = {
            start = vim.api.nvim_buf_get_mark(0, "<"),
            ["end"] = vim.api.nvim_buf_get_mark(0, ">"),
        }})
    end, "Format selection")
end

-- Treesitter 
local ts_ok, ts = pcall(require, "nvim-treesitter.configs")
if ts_ok then
    ts.setup({
        ensure_installed = { "lua", "python", "go", "bash", "json", "yaml", "markdown" },
        highlight        = { enable = true },
        indent           = { enable = true },
    })
end
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true

-- Git signs 
local gs_ok, gitsigns = pcall(require, "gitsigns")
if gs_ok then
    gitsigns.setup({
        on_attach = function(bufnr)
            local gs = package.loaded.gitsigns
            local function map(mode, l, r, desc)
                vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
            end
            map("n", "]h", gs.next_hunk,            "Next hunk")
            map("n", "[h", gs.prev_hunk,            "Prev hunk")
            map("n", "<leader>hs", gs.stage_hunk,   "Stage hunk")
            map("n", "<leader>hr", gs.reset_hunk,   "Reset hunk")
            map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
            map("n", "<leader>hb", gs.blame_line,   "Blame line")
        end,
    })
end

-- uv.nvim
local uv_ok, uv = pcall(require, "uv")
if uv_ok then
    uv.setup({
      -- Auto-activate virtual environments when found
      auto_activate_venv = true,
      notify_activate_venv = true,

      -- Integration with a UI picker (remove if you don't use snacks/telescope)
      picker_integration = true,

      -- Keymaps (uses <leader>x prefix by default)
      keymaps = {
        prefix = "<leader>x",
        commands = true,
        run_file = true,
        run_selection = true,
        run_function = true,
        venv = true,
        init = true,
        add = true,
        remove = true,
        sync = true,
      },

      execution = {
        run_command = "uv run python",
        notify_output = true,
        notification_timeout = 10000,
      },
    })
end

-- lualine
local lualine_ok, lualine = pcall(require, "lualine")
if lualine_ok then
    lualine.setup({
        options = {
            icons_enabled = true,
            theme = "auto",
            disabled_buftypes = { "terminal", "nofile", "prompt", "quickfix" },
            -- component_separators = { left = "|", right = "|" },
            -- section_separators = { left = "", right = "" },
        },
        sections = {
            lualine_a = { "mode" },
            lualine_b = { "branch", "diff" },
            lualine_c = { "filename", "diagnostics" },
            lualine_x = { "filetype" },
            lualine_y = { "progress" },
            lualine_z = { "location" },
        },
        tabline = {
            lualine_a = { {
                "buffers",
                show_filename_only = true,
                hide_filename_extension = false,
                show_modified_status = true,
                buffers_color = {
                    active   = "lualine_a_normal",
                    inactive = "lualine_c_normal",
                },
            } },
            lualine_b = {},
            lualine_c = {},
            lualine_x = {},
            lualine_y = {},
            lualine_z = {},
        },
    })
end

-- Render markdown
require("render-markdown").setup()



-- snacks picker
local picker_ok = pcall(require, "snacks")
if picker_ok then
    local pk = require("snacks").picker
    map("n", "<leader>ff", function() pk.files() end,       "Find files")
    map("n", "<leader>fg", function() pk.grep() end,        "Live grep")
    map("n", "<leader>t", function() pk.buffers() end, "List of open buffers" )
    map("n", "<leader>fh", function() pk.help() end,        "Help tags")
    map("n", "<leader>fd", function() pk.diagnostics() end, "Diagnostics")
    map("n", "<leader>p", function() pk.keymaps() end, "Select Keymap to run" ) 
end

-- Winbar breadcrumbs
local navic_ok_winbar, navic_winbar = pcall(require, "nvim-navic")
if navic_ok_winbar then
    vim.opt.winbar = "%{%v:lua.require'nvim-navic'.get_location()%}"
end

-- snacks explorer
local explorer_ok = pcall(require, "snacks")
if explorer_ok then
    map("n", "<leader>b", function() require("snacks").explorer.open() end, "Toggle file tree")
end

-- LSP extras (0.12 built-ins cover gra/grn/grr/gri/grt already)
map("n", "<leader>ld", vim.lsp.buf.definition,     "Go to definition")
map("n", "<leader>lh", function()
    vim.lsp.buf.hover({
        border = "rounded",
        focus = "always",
        max_width = 80,
        max_height = 20,
    })
end, "Hover docs")
map("n", "<leader>ls", vim.lsp.buf.signature_help, "Signature help")
map("n", "<leader>lf", vim.lsp.buf.format,         "LSP format")

-- Ctrl-Space triggers nvim-cmp (configured above)

-- Diagnostics
map("n", "[d",        vim.diagnostic.goto_prev,  "Prev diagnostic")
map("n", "]d",        vim.diagnostic.goto_next,  "Next diagnostic")
map("n", "<leader>e", vim.diagnostic.open_float, "Diagnostic float")

-- Window navigation
map("n", "<C-h>", "<C-w>h", "Move to left window")
map("n", "<C-j>", "<C-w>j", "Move to lower window")
map("n", "<C-k>", "<C-w>k", "Move to upper window")
map("n", "<C-l>", "<C-w>l", "Move to right window")

-- Buffer navigation
map("n", "<leader><Tab>", "<Cmd>bnext<CR>", "Open next buffer")
map("n", "<leader><S-Tab>", "<Cmd>bprevious<CR>", "Open previous buffer")


-- Misc
map("n", "<Esc>",     "<cmd>nohlsearch<CR>", "Clear search highlight")
map("n", "<leader>w", "<cmd>write<CR>",      "Save")
map("n", "<leader>q", "<cmd>quit<CR>",       "Quit")
map("n", "<leader>u", "<cmd>packadd nvim.undotree | Undotree<CR>", "Undotree")

-- Colorscheme 
vim.cmd.colorscheme("carbonfox")

