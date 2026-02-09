local config = require("diff-review.config")

describe("config", function()
  before_each(function()
    -- Reset config before each test
    config.options = {}
  end)

  describe("defaults", function()
    it("should have default status configuration", function()
      local defaults = config.defaults
      assert.is_not_nil(defaults.ui.status)
      assert.is_not_nil(defaults.ui.status.symbols)
      assert.is_not_nil(defaults.ui.status.highlights)
    end)

    it("should have correct default status symbols", function()
      local defaults = config.defaults
      assert.equals("M", defaults.ui.status.symbols.modified)
      assert.equals("A", defaults.ui.status.symbols.added)
      assert.equals("D", defaults.ui.status.symbols.deleted)
      assert.equals("R", defaults.ui.status.symbols.renamed)
    end)

    it("should have correct default status highlights", function()
      local defaults = config.defaults
      assert.equals("DiffChange", defaults.ui.status.highlights.modified)
      assert.equals("DiffAdd", defaults.ui.status.highlights.added)
      assert.equals("DiffDelete", defaults.ui.status.highlights.deleted)
      assert.equals("DiffReviewRenamed", defaults.ui.status.highlights.renamed)
    end)
  end)

  describe("setup", function()
    it("should use default status config when no custom config provided", function()
      local opts = config.setup({})
      assert.equals("M", opts.ui.status.symbols.modified)
      assert.equals("A", opts.ui.status.symbols.added)
      assert.equals("D", opts.ui.status.symbols.deleted)
      assert.equals("R", opts.ui.status.symbols.renamed)
    end)

    it("should override status symbols when provided", function()
      local opts = config.setup({
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
      assert.equals("[M]", opts.ui.status.symbols.modified)
      assert.equals("[A]", opts.ui.status.symbols.added)
      assert.equals("[D]", opts.ui.status.symbols.deleted)
      assert.equals("[R]", opts.ui.status.symbols.renamed)
    end)

    it("should override status highlights when provided", function()
      local opts = config.setup({
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
      assert.equals("WarningMsg", opts.ui.status.highlights.modified)
      assert.equals("String", opts.ui.status.highlights.added)
      assert.equals("ErrorMsg", opts.ui.status.highlights.deleted)
      assert.equals("Function", opts.ui.status.highlights.renamed)
    end)

    it("should allow partial override of status symbols", function()
      local opts = config.setup({
        ui = {
          status = {
            symbols = {
              modified = "MOD",
            },
          },
        },
      })
      assert.equals("MOD", opts.ui.status.symbols.modified)
      assert.equals("A", opts.ui.status.symbols.added)
      assert.equals("D", opts.ui.status.symbols.deleted)
      assert.equals("R", opts.ui.status.symbols.renamed)
    end)

    it("should preserve other ui config when setting status", function()
      local opts = config.setup({
        ui = {
          border = "single",
          show_icons = false,
          status = {
            symbols = {
              modified = "M",
            },
          },
        },
      })
      assert.equals("single", opts.ui.border)
      assert.is_false(opts.ui.show_icons)
      assert.equals("M", opts.ui.status.symbols.modified)
    end)
  end)

  describe("get", function()
    it("should return configured options", function()
      config.setup({
        ui = {
          status = {
            symbols = {
              modified = "TEST",
            },
          },
        },
      })
      local opts = config.get()
      assert.equals("TEST", opts.ui.status.symbols.modified)
    end)
  end)
end)
