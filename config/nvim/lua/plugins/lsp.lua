return {
  -- Mason: gestiona LSP servers
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason.nvim" },
    opts = function()
      local is_mac = vim.uv.os_uname().sysname == "Darwin"
      local servers = {
        "pyright", "lua_ls", "yamlls", "jsonls",
        "bashls", "dockerls", "ts_ls", "ansiblels",
      }
      if is_mac then
        vim.list_extend(servers, { "gopls", "terraformls" })
      end
      return { ensure_installed = servers }
    end,
  },

  -- LSP config (nvim 0.11+ API — sin require('lspconfig')[server].setup())
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason.nvim",
      "mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Aplicar capabilities a todos los servidores globalmente
      vim.lsp.config("*", { capabilities = capabilities })

      -- Configuración específica por servidor
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      -- Habilitar servidores según OS
      local is_mac = vim.uv.os_uname().sysname == "Darwin"
      local servers = {
        "pyright", "lua_ls", "yamlls", "jsonls",
        "bashls", "dockerls", "ts_ls", "ansiblels",
      }
      if is_mac then
        vim.list_extend(servers, { "gopls", "terraformls" })
      end
      vim.lsp.enable(servers)

      -- Keymaps LSP (se activan al conectar un servidor)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = ev.buf, desc = desc })
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "References")
          map("K", vim.lsp.buf.hover, "Hover")
          map("<Leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<Leader>rn", vim.lsp.buf.rename, "Rename")
          map("[d", vim.diagnostic.goto_prev, "Prev diagnostic")
          map("]d", vim.diagnostic.goto_next, "Next diagnostic")
        end,
      })
    end,
  },

  -- Autocompletado
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<C-d>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = {
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        },
      })
    end,
  },

  -- Formatters
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = {
        python = { "ruff_format" },
        go = { "goimports", "gofmt" },
        json = { "jq" },
        -- tofu_fmt y no terraform_fmt: el binario que declaran Brewfile.cloud y
        -- lib/binaries.sh es `tofu` en las dos plataformas. Con terraform_fmt
        -- esto daba ENOENT en cada .tf en Linux, donde terraform nunca se
        -- instaló.
        terraform = { "tofu_fmt" },
        lua = { "stylua" },
      },
      format_on_save = { timeout_ms = 3000, lsp_fallback = true },
    },
  },

  -- Linters
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        python = { "ruff" },
        yaml = { "yamllint" },
        sh = { "shellcheck" },
        terraform = { "tflint" },
      }
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        callback = function() lint.try_lint() end,
      })
    end,
  },
}
