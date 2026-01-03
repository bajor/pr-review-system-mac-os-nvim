.PHONY: test test-nvim test-app lint lint-nvim lint-app build build-app clean setup help

VERSION := $(shell cat VERSION)

# Default target
help:
	@echo "PR Review System - v$(VERSION)"
	@echo ""
	@echo "Usage:"
	@echo "  make test       Run all tests and linting"
	@echo "  make test-nvim  Run Neovim plugin tests"
	@echo "  make test-app   Run Swift app tests"
	@echo "  make lint       Run all linters"
	@echo "  make lint-nvim  Run Lua linting (stylua)"
	@echo "  make lint-app   Run Swift linting (swiftlint)"
	@echo "  make build-app  Build the macOS app"
	@echo "  make clean      Remove build artifacts"
	@echo "  make setup      Create config directories"

# Master test target (required by CLAUDE.md guidelines)
test: lint test-nvim test-app
	@echo "All tests passed!"

# Linting
lint: lint-nvim lint-app

lint-nvim:
	@echo "==> Checking Lua formatting with StyLua..."
	@if command -v stylua >/dev/null 2>&1; then \
		stylua --check nvim/ || (echo "Run 'stylua nvim/' to fix formatting" && exit 1); \
	else \
		echo "stylua not found, skipping Lua lint (install with: brew install stylua)"; \
	fi

lint-app:
	@echo "==> Running SwiftLint..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		cd app && swiftlint lint --quiet; \
	else \
		echo "swiftlint not found, skipping Swift lint (install with: brew install swiftlint)"; \
	fi

# Testing
test-nvim:
	@echo "==> Running Neovim plugin tests..."
	@nvim --headless --noplugin -u nvim/tests/minimal_init.lua \
		-c "PlenaryBustedDirectory nvim/tests/ {minimal_init = 'nvim/tests/minimal_init.lua'}"

test-app:
	@echo "==> Running Swift tests..."
	@cd app && swift test --quiet 2>/dev/null || swift test

# Building
build: build-app

build-app:
	@echo "==> Building macOS app..."
	@cd app && swift build -c release
	@echo "Binary at: app/.build/release/PRReviewSystem"

# Cleanup
clean:
	@echo "==> Cleaning build artifacts..."
	@cd app && swift package clean 2>/dev/null || true
	@rm -rf app/.build app/.swiftpm

# Setup
setup:
	@echo "==> Creating config directories..."
	@mkdir -p ~/.config/pr-review
	@mkdir -p ~/.local/share/pr-review/repos
	@echo "Created:"
	@echo "  ~/.config/pr-review/"
	@echo "  ~/.local/share/pr-review/repos/"
	@echo ""
	@echo "Now create ~/.config/pr-review/config.json with your settings."
