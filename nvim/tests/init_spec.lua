describe("pr-review", function()
  it("can be required", function()
    local pr_review = require("pr-review")
    assert.is_not_nil(pr_review)
  end)

  it("has setup function", function()
    local pr_review = require("pr-review")
    assert.is_function(pr_review.setup)
  end)

  it("setup accepts empty options", function()
    local pr_review = require("pr-review")
    -- Should not error
    pr_review.setup({})
    assert.is_table(pr_review.config)
  end)

  it("setup merges user options", function()
    local pr_review = require("pr-review")
    pr_review.setup({ custom_option = "test" })
    assert.equals("test", pr_review.config.custom_option)
  end)
end)
