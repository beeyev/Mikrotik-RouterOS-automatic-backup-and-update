# RouterOS lab. See README.md.

.DEFAULT_GOAL := help
SHELL := bash
MAKEFLAGS += --no-print-directory

# KVM when the host has it; QEMU falls back to slower CPU emulation.
COMPOSE := docker compose -f compose.yaml$(if $(wildcard /dev/kvm), -f compose.kvm.yaml)

# Passed through the environment so quotes and spaces survive.
export CMD

.PHONY: help up down restart ssh ros

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  %-8s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

up: ## Start a fresh lab and wait until RouterOS is ready
	$(COMPOSE) up --detach --build --wait --wait-timeout 900

down: ## Stop the lab and discard all state
	$(COMPOSE) down --remove-orphans

restart: ## Recreate the lab from scratch
	@$(MAKE) down
	@$(MAKE) up

ssh: ## Open a RouterOS terminal
	@$(COMPOSE) exec toolbox lab ros

ros: ## Run a RouterOS command: make ros CMD='/system resource print'
	@if [[ -z "$${CMD:-}" ]]; then echo "usage: make ros CMD='<RouterOS command>'" >&2; exit 2; fi
	@$(COMPOSE) exec -T toolbox lab ros "$$CMD"
