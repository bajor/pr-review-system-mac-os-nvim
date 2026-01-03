local keymaps = require("pr-review.keymaps")

describe("pr-review.keymaps", function()
  after_each(function()
    -- Clean up keymaps after each test
    keymaps.clear()
  end)

  describe("module", function()
    it("can be required", function()
      assert.is_not_nil(keymaps)
    end)

    it("has keymaps table", function()
      assert.is_table(keymaps.keymaps)
    end)

    it("has setup function", function()
      assert.is_function(keymaps.setup)
    end)

    it("has clear function", function()
      assert.is_function(keymaps.clear)
    end)

    it("has setup_buffer function", function()
      assert.is_function(keymaps.setup_buffer)
    end)

    it("has get_help function", function()
      assert.is_function(keymaps.get_help)
    end)

    it("has show_help function", function()
      assert.is_function(keymaps.show_help)
    end)
  end)

  describe("keymaps table", function()
    it("has file navigation keymaps", function()
      local has_next_file = false
      local has_prev_file = false

      for _, km in ipairs(keymaps.keymaps) do
        if km.lhs == "]f" then has_next_file = true end
        if km.lhs == "[f" then has_prev_file = true end
      end

      assert.is_true(has_next_file)
      assert.is_true(has_prev_file)
    end)

    it("has comment navigation keymaps", function()
      local has_next_comment = false
      local has_prev_comment = false

      for _, km in ipairs(keymaps.keymaps) do
        if km.lhs == "]c" then has_next_comment = true end
        if km.lhs == "[c" then has_prev_comment = true end
      end

      assert.is_true(has_next_comment)
      assert.is_true(has_prev_comment)
    end)

    it("has comment action keymaps", function()
      local has_create = false
      local has_list = false
      local has_resolve = false

      for _, km in ipairs(keymaps.keymaps) do
        if km.lhs == "<leader>cc" then has_create = true end
        if km.lhs == "<leader>lc" then has_list = true end
        if km.lhs == "<leader>rc" then has_resolve = true end
      end

      assert.is_true(has_create)
      assert.is_true(has_list)
      assert.is_true(has_resolve)
    end)

    it("all keymaps have mode, lhs, rhs, and desc", function()
      for _, km in ipairs(keymaps.keymaps) do
        assert.is_string(km.mode)
        assert.is_string(km.lhs)
        assert.is_not_nil(km.rhs)
        assert.is_string(km.desc)
      end
    end)
  end)

  describe("setup", function()
    it("sets up keymaps without error", function()
      -- Should not error
      keymaps.setup()
    end)
  end)

  describe("clear", function()
    it("clears keymaps without error", function()
      keymaps.setup()
      -- Should not error
      keymaps.clear()
    end)

    it("handles clearing when not setup", function()
      -- Should not error even if keymaps weren't setup
      keymaps.clear()
    end)
  end)

  describe("setup_buffer", function()
    it("handles nil buffer", function()
      -- Should not error
      keymaps.setup_buffer(nil)
    end)

    it("handles invalid buffer", function()
      -- Should not error
      keymaps.setup_buffer(-1)
    end)

    it("sets up keymaps for valid buffer", function()
      local buf = vim.api.nvim_create_buf(false, true)
      -- Should not error
      keymaps.setup_buffer(buf)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("get_help", function()
    it("returns array of strings", function()
      local help = keymaps.get_help()
      assert.is_table(help)
      assert.is_true(#help > 0)
      for _, line in ipairs(help) do
        assert.is_string(line)
      end
    end)

    it("includes header", function()
      local help = keymaps.get_help()
      assert.equals("PR Review Keymaps:", help[1])
    end)

    it("includes all categories", function()
      local help = keymaps.get_help()
      local text = table.concat(help, "\n")
      assert.is_truthy(text:match("File Navigation"))
      assert.is_truthy(text:match("Comment Navigation"))
      assert.is_truthy(text:match("Comment Actions"))
    end)
  end)
end)
