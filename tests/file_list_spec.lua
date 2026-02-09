local config = require("diff-review.config")

describe("file_list status icons", function()
  before_each(function()
    -- Reset config before each test
    config.options = {}
  end)

  -- Helper to get status icons (we need to access the internal function)
  local function get_status_icons_for_test()
    -- Since get_status_icons is local, we test it through the behavior
    -- by setting up config and checking the rendering output
    local file_list = require("diff-review.file_list")
    -- We'll need to reload the module to pick up config changes
    package.loaded["diff-review.file_list"] = nil
    return require("diff-review.file_list")
  end

  describe("default status icons", function()
    it("should use letter symbols by default", function()
      config.setup({})
      local opts = config.get()

      -- Verify the config has the right defaults
      assert.equals("M", opts.ui.status.symbols.modified)
      assert.equals("A", opts.ui.status.symbols.added)
      assert.equals("D", opts.ui.status.symbols.deleted)
      assert.equals("R", opts.ui.status.symbols.renamed)
    end)

    it("should use correct highlight groups by default", function()
      config.setup({})
      local opts = config.get()

      assert.equals("DiffChange", opts.ui.status.highlights.modified)
      assert.equals("DiffAdd", opts.ui.status.highlights.added)
      assert.equals("DiffDelete", opts.ui.status.highlights.deleted)
      assert.equals("DiffReviewRenamed", opts.ui.status.highlights.renamed)
    end)
  end)

  describe("custom status icons", function()
    it("should use custom symbols when configured", function()
      config.setup({
        ui = {
          status = {
            symbols = {
              modified = "[M]",
              added = "[A]",
              deleted = "[D]",
              renamed = "[R]",
            },
          },
        },
      })
      local opts = config.get()

      assert.equals("[M]", opts.ui.status.symbols.modified)
      assert.equals("[A]", opts.ui.status.symbols.added)
      assert.equals("[D]", opts.ui.status.symbols.deleted)
      assert.equals("[R]", opts.ui.status.symbols.renamed)
    end)

    it("should use custom highlight groups when configured", function()
      config.setup({
        ui = {
          status = {
            highlights = {
              modified = "WarningMsg",
              added = "String",
              deleted = "ErrorMsg",
              renamed = "Function",
            },
          },
        },
      })
      local opts = config.get()

      assert.equals("WarningMsg", opts.ui.status.highlights.modified)
      assert.equals("String", opts.ui.status.highlights.added)
      assert.equals("ErrorMsg", opts.ui.status.highlights.deleted)
      assert.equals("Function", opts.ui.status.highlights.renamed)
    end)

    it("should support longer text symbols", function()
      config.setup({
        ui = {
          status = {
            symbols = {
              modified = "MOD",
              added = "NEW",
              deleted = "DEL",
              renamed = "REN",
            },
          },
        },
      })
      local opts = config.get()

      assert.equals("MOD", opts.ui.status.symbols.modified)
      assert.equals("NEW", opts.ui.status.symbols.added)
      assert.equals("DEL", opts.ui.status.symbols.deleted)
      assert.equals("REN", opts.ui.status.symbols.renamed)
    end)

    it("should fall back to defaults if status config is nil", function()
      config.setup({
        ui = {
          border = "rounded",
        },
      })
      local opts = config.get()

      -- Should have defaults even though status wasn't explicitly set
      assert.equals("M", opts.ui.status.symbols.modified)
      assert.equals("A", opts.ui.status.symbols.added)
      assert.equals("D", opts.ui.status.symbols.deleted)
      assert.equals("R", opts.ui.status.symbols.renamed)
    end)

    it("should merge partial symbol overrides with defaults", function()
      config.setup({
        ui = {
          status = {
            symbols = {
              modified = "MODIFIED",
              -- Others should use defaults
            },
          },
        },
      })
      local opts = config.get()

      assert.equals("MODIFIED", opts.ui.status.symbols.modified)
      assert.equals("A", opts.ui.status.symbols.added)
      assert.equals("D", opts.ui.status.symbols.deleted)
      assert.equals("R", opts.ui.status.symbols.renamed)
    end)
  end)

  describe("backwards compatibility", function()
    it("should work when no status config is provided", function()
      -- Simulate old config without status section
      config.setup({
        ui = {
          border = "rounded",
          show_icons = true,
        },
      })
      local opts = config.get()

      -- Should still have status config from defaults
      assert.is_not_nil(opts.ui.status)
      assert.is_not_nil(opts.ui.status.symbols)
      assert.is_not_nil(opts.ui.status.highlights)
    end)
  end)
end)
