# RouterOS lab. See README.md.

# Passed through the environment so quotes and spaces survive.
export CMD

.PHONY: help up down ssh ros

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  %-6s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

up: ## Start the lab and wait until RouterOS is configured
	docker compose up --detach --build
	@echo "Configuring RouterOS..."
	@if [ "$$(docker wait bkpupd-lab-toolbox)" != 0 ]; then docker logs bkpupd-lab-toolbox; exit 1; fi
	@echo
	@echo "RouterOS lab is ready. Login: admin / admin"
	@echo "  SSH      $$(docker compose port routeros 22)"
	@echo "  WebFig   http://$$(docker compose port routeros 80)"
	@echo "  WinBox   $$(docker compose port routeros 8291)"
	@echo "  Mailpit  http://$$(docker compose port mailpit 8025)"

down: ## Stop the lab and discard all state
	docker compose down --remove-orphans

ssh: ## Open a RouterOS terminal
	@docker compose --progress quiet run --rm --no-deps toolbox lab ros

ros: ## Run a RouterOS command: make ros CMD='/system resource print'
	$(if $(CMD),,$(error usage: make ros CMD='<RouterOS command>'))
	@docker compose --progress quiet run --rm --no-deps -T toolbox lab ros "$$CMD"
