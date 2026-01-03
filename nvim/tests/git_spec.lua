local git = require("pr-review.git")

describe("pr-review.git", function()
  describe("module", function()
    it("can be required", function()
      assert.is_not_nil(git)
    end)

    it("has clone function", function()
      assert.is_function(git.clone)
    end)

    it("has fetch_reset function", function()
      assert.is_function(git.fetch_reset)
    end)

    it("has get_current_branch function", function()
      assert.is_function(git.get_current_branch)
    end)

    it("has get_current_sha function", function()
      assert.is_function(git.get_current_sha)
    end)

    it("has is_git_repo function", function()
      assert.is_function(git.is_git_repo)
    end)

    it("has get_remote_url function", function()
      assert.is_function(git.get_remote_url)
    end)

    it("has build_pr_path function", function()
      assert.is_function(git.build_pr_path)
    end)
  end)

  describe("build_pr_path", function()
    it("builds correct path", function()
      local path = git.build_pr_path("/home/user/repos", "owner", "repo", 123)
      assert.equals("/home/user/repos/owner/repo/pr-123", path)
    end)

    it("handles different PR numbers", function()
      local path = git.build_pr_path("/tmp/prs", "org", "project", 1)
      assert.equals("/tmp/prs/org/project/pr-1", path)
    end)

    it("handles large PR numbers", function()
      local path = git.build_pr_path("/data", "company", "app", 99999)
      assert.equals("/data/company/app/pr-99999", path)
    end)
  end)

  describe("is_git_repo", function()
    it("returns true for git repository", function()
      -- The project root should be a git repo
      local project_root = vim.fn.getcwd()
      assert.is_true(git.is_git_repo(project_root))
    end)

    it("returns false for non-git directory", function()
      assert.is_false(git.is_git_repo("/tmp"))
    end)

    it("returns false for non-existent directory", function()
      assert.is_false(git.is_git_repo("/nonexistent/path/12345"))
    end)
  end)

  -- Integration tests for actual git operations
  describe("get_current_branch", function()
    it("gets branch name for current repo", function()
      local done = false
      local result_branch = nil

      git.get_current_branch(vim.fn.getcwd(), function(branch, err)
        result_branch = branch
        done = true
      end)

      -- Wait for async operation
      vim.wait(5000, function()
        return done
      end)

      assert.is_true(done)
      assert.is_not_nil(result_branch)
      -- Should be a valid branch name (non-empty string)
      assert.is_string(result_branch)
      assert.is_true(#result_branch > 0)
    end)
  end)

  describe("get_current_sha", function()
    it("gets SHA for current repo", function()
      local done = false
      local result_sha = nil

      git.get_current_sha(vim.fn.getcwd(), function(sha, err)
        result_sha = sha
        done = true
      end)

      -- Wait for async operation
      vim.wait(5000, function()
        return done
      end)

      assert.is_true(done)
      assert.is_not_nil(result_sha)
      -- SHA should be 40 hex characters
      assert.equals(40, #result_sha)
      assert.is_truthy(result_sha:match("^[0-9a-f]+$"))
    end)
  end)

  describe("get_remote_url", function()
    it("gets remote URL for current repo", function()
      local done = false
      local result_url = nil

      git.get_remote_url(vim.fn.getcwd(), function(url, err)
        result_url = url
        done = true
      end)

      -- Wait for async operation
      vim.wait(5000, function()
        return done
      end)

      assert.is_true(done)
      -- Remote URL might not exist for a fresh repo
      -- Just check the callback was called
    end)
  end)
end)
