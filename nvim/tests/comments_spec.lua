local comments = require("pr-review.comments")
local state = require("pr-review.state")

describe("pr-review.comments", function()
  before_each(function()
    state.reset()
  end)

  describe("module", function()
    it("can be required", function()
      assert.is_not_nil(comments)
    end)

    it("has show_comments function", function()
      assert.is_function(comments.show_comments)
    end)

    it("has clear_comments function", function()
      assert.is_function(comments.clear_comments)
    end)

    it("has get_buffer_comments function", function()
      assert.is_function(comments.get_buffer_comments)
    end)

    it("has find_next_comment function", function()
      assert.is_function(comments.find_next_comment)
    end)

    it("has find_prev_comment function", function()
      assert.is_function(comments.find_prev_comment)
    end)

    it("has next_comment function", function()
      assert.is_function(comments.next_comment)
    end)

    it("has prev_comment function", function()
      assert.is_function(comments.prev_comment)
    end)

    it("has show_comment_popup function", function()
      assert.is_function(comments.show_comment_popup)
    end)

    it("has create_comment function", function()
      assert.is_function(comments.create_comment)
    end)

    it("has list_comments function", function()
      assert.is_function(comments.list_comments)
    end)

    it("has toggle_resolved function", function()
      assert.is_function(comments.toggle_resolved)
    end)

    it("has get_pending_comments function", function()
      assert.is_function(comments.get_pending_comments)
    end)

    it("has submit_comments function", function()
      assert.is_function(comments.submit_comments)
    end)

    it("has get_namespace function", function()
      assert.is_function(comments.get_namespace)
    end)
  end)

  describe("get_namespace", function()
    it("returns a namespace ID", function()
      local ns = comments.get_namespace()
      assert.is_number(ns)
      assert.is_true(ns > 0)
    end)
  end)

  describe("get_buffer_comments", function()
    it("returns empty array when no session", function()
      local result = comments.get_buffer_comments()
      assert.is_table(result)
      assert.equals(0, #result)
    end)
  end)

  describe("find_next_comment", function()
    it("returns nil when no comments", function()
      local comment, line = comments.find_next_comment()
      assert.is_nil(comment)
      assert.is_nil(line)
    end)
  end)

  describe("find_prev_comment", function()
    it("returns nil when no comments", function()
      local comment, line = comments.find_prev_comment()
      assert.is_nil(comment)
      assert.is_nil(line)
    end)
  end)

  describe("get_pending_comments", function()
    it("returns empty array when no session", function()
      local pending = comments.get_pending_comments()
      assert.is_table(pending)
      assert.equals(0, #pending)
    end)

    it("returns empty array when no pending comments", function()
      state.start({ owner = "o", repo = "r", number = 1 })
      state.set_files({ { filename = "test.lua" } })
      state.set_comments("test.lua", {
        { line = 1, body = "not pending", pending = false },
      })

      local pending = comments.get_pending_comments()
      assert.is_table(pending)
      assert.equals(0, #pending)
    end)

    it("returns pending comments", function()
      state.start({ owner = "o", repo = "r", number = 1 })
      state.set_files({ { filename = "test.lua" } })
      state.set_comments("test.lua", {
        { line = 1, body = "pending comment", pending = true },
        { line = 2, body = "not pending", pending = false },
        { line = 3, body = "another pending", pending = true },
      })

      local pending = comments.get_pending_comments()
      assert.is_table(pending)
      assert.equals(2, #pending)
    end)
  end)

  describe("show_comments", function()
    it("handles nil buffer", function()
      -- Should not error
      comments.show_comments(nil, {})
    end)

    it("handles invalid buffer", function()
      -- Should not error
      comments.show_comments(-1, {})
    end)

    it("handles nil comments", function()
      local buf = vim.api.nvim_create_buf(false, true)
      -- Should not error
      comments.show_comments(buf, nil)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("handles empty comments", function()
      local buf = vim.api.nvim_create_buf(false, true)
      -- Should not error
      comments.show_comments(buf, {})
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("clear_comments", function()
    it("handles nil buffer", function()
      -- Should not error
      comments.clear_comments(nil)
    end)

    it("handles invalid buffer", function()
      -- Should not error
      comments.clear_comments(-1)
    end)
  end)

  describe("create_comment", function()
    it("warns when no active session", function()
      -- Should not error, just warn
      comments.create_comment()
    end)
  end)
end)
