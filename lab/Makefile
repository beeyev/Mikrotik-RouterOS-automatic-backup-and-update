# RouterOS lab. See README.md.

# Passed through the environment so quotes and spaces survive.
export CMD

.PHONY: help up down ssh ros

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  %-6s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

up: ## Start the lab and wait until RouterOS is configured
	docker compose up --detach --build
	docker compose logs --follow toolbox
	docker compose wait toolbox >/dev/null

down: ## Stop the lab and discard all state
	docker compose down --remove-orphans

ssh: ## Open a RouterOS terminal
	@docker compose --progress quiet run --rm --no-deps toolbox lab ros

ros: ## Run a RouterOS command: make ros CMD='/system resource print'
	$(if $(CMD),,$(error usage: make ros CMD='<RouterOS command>'))
	@docker compose --progress quiet run --rm --no-deps -T toolbox lab ros "$$CMD"
