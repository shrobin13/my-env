#!/usr/bin/env bash
# ~/.dotfiles/Makefile
# Build and maintenance tasks

.PHONY: help install install-dry build clean validate lint test update logs status

DOTFILES_DIR := $(shell pwd)
SHELL := /bin/bash

help:
	@echo "Hyprland Platform - Build Tasks"
	@echo ""
	@echo "Installation:"
	@echo "  make install           Install with default profile (laptop)"
	@echo "  make install-dry       Dry run (show what would be done)"
	@echo "  make install PROFILE=workstation   Install workstation profile"
	@echo ""
	@echo "Configuration:"
	@echo "  make build             Generate runtime configs"
	@echo "  make validate          Validate all configurations"
	@echo "  make lint              Lint Lua/shell scripts"
	@echo ""
	@echo "Maintenance:"
	@echo "  make update            Update all packages"
	@echo "  make clean             Clean cache/generated files"
	@echo "  make logs              Show last 100 lines of logs"
	@echo "  make status            Show platform status"
	@echo ""

install:
	@bash $(DOTFILES_DIR)/bootstrap.sh \
		--profile $(PROFILE) \
		--theme $(THEME)

install-dry:
	@bash $(DOTFILES_DIR)/bootstrap.sh \
		--profile $(PROFILE) \
		--theme $(THEME) \
		--dry-run

build:
	@echo "📦 Building configurations..."
	@lua $(DOTFILES_DIR)/scripts/internal/config-generator.lua generate-all
	@echo "✅ Configurations built"

validate:
	@echo "🔍 Validating configurations..."
	@bash -n $(DOTFILES_DIR)/bootstrap.sh
	@for script in $(DOTFILES_DIR)/scripts/**/*.sh; do bash -n $$script; done
	@echo "✅ All validations passed"

lint:
	@echo "🔍 Linting Lua scripts..."
	@for lua_file in $(DOTFILES_DIR)/modules/**/*.lua; do \
		luac -p $$lua_file && echo "✓ $$lua_file" || exit 1; \
	done
	@echo "✅ All Lua scripts valid"

test:
	@echo "🧪 Running tests..."
	@echo "Note: Comprehensive test suite would be implemented here"
	@make validate

update:
	@echo "📦 Updating packages..."
	@if [ -f $(DOTFILES_DIR)/packages/core.yaml ]; then \
		echo "Running pacman update..."; \
		sudo pacman -Syu; \
	fi
	@echo "✅ Update complete"

clean:
	@echo "🗑️  Cleaning cache and generated files..."
	@rm -rf $(DOTFILES_DIR)/runtime/cache/compiled/* \
	        $(DOTFILES_DIR)/runtime/cache/thumbnails/* \
	        $(DOTFILES_DIR)/runtime/gen/*
	@echo "✅ Cleanup complete"

logs:
	@echo "📋 Last 100 lines of logs:"
	@tail -100 $(DOTFILES_DIR)/state/logs/*.log 2>/dev/null || \
		echo "No logs found"

status:
	@echo "📊 Platform Status"
	@echo "================================"
	@echo "Config hash: $$(cat $(DOTFILES_DIR)/runtime/config-hash 2>/dev/null || echo 'unknown')"
	@echo "Current theme: $$(cat $(DOTFILES_DIR)/runtime/current-wallpaper 2>/dev/null || echo 'unknown')"
	@echo "Cache size: $$(du -sh $(DOTFILES_DIR)/runtime/cache 2>/dev/null || echo '0B')"
	@echo "State size: $$(du -sh $(DOTFILES_DIR)/state 2>/dev/null || echo '0B')"
	@echo ""
	@if pgrep hyprland > /dev/null; then \
		echo "✓ Hyprland is running"; \
		hyprctl version 2>/dev/null | head -1; \
	else \
		echo "✗ Hyprland is not running"; \
	fi
	@echo ""
	@if pgrep waybar > /dev/null; then \
		echo "✓ Waybar is running"; \
	else \
		echo "✗ Waybar is not running"; \
	fi
	@echo ""

# Phony targets
.PHONY: install install-dry build validate lint test update clean logs status help
