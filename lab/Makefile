# RouterOS lab. See README.md.

# RouterOS major version for ssh, ros and script.
V ?= 7
ROUTER = $(if $(filter 6 7,$(V)),routeros$(V),$(error V must be 6 or 7, got '$(V)'))
port = $$(docker compose port $(1) $(2))

# Passed through the environment so quotes and spaces survive. $(value)
# keeps make from expanding RouterOS variables such as $x.
override CMD := $(value CMD)
export CMD

.PHONY: help up down ssh ros script

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  %-6s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

up: ## Start the lab and wait until both routers are configured
	docker compose up --detach --build
	@docker logs --follow bkpupd-lab-toolbox
	@test "$$(docker wait bkpupd-lab-toolbox)" = 0
	@echo
	@echo "RouterOS lab is ready. Login: admin / admin"
	@echo "  v7  SSH $(call port,routeros7,22)  WebFig http://$(call port,routeros7,80)  WinBox $(call port,routeros7,8291)"
	@echo "  v6  SSH $(call port,routeros6,22)  WebFig http://$(call port,routeros6,80)  WinBox $(call port,routeros6,8291)"
	@echo "  Mailpit http://$(call port,mailpit,8025)"

down: ## Stop the lab and discard all state
	docker compose down --remove-orphans

ssh: ## Open a RouterOS terminal: make ssh [V=6]
	@echo "Type /quit or press Ctrl+D to leave the RouterOS terminal."
	@docker compose --progress quiet run --rm --no-deps toolbox lab ros $(ROUTER)

ros: ## Run a RouterOS command: make ros [V=6] CMD='/system resource print'
	$(if $(CMD),,$(error usage: make ros [V=6] CMD='<RouterOS command>'))
	@docker compose --progress quiet run --rm --no-deps -T toolbox lab ros $(ROUTER) "$$CMD"

script: ## Load ../BackupAndUpdate.rsc into RouterOS: make script [V=6]
	@grep -q '^:local anonStats true$$' ../BackupAndUpdate.rsc || { echo "anonStats line not found in ../BackupAndUpdate.rsc" >&2; exit 1; }
	@sed 's/^:local anonStats true/:local anonStats false/' ../BackupAndUpdate.rsc \
		| docker compose --progress quiet run --rm --no-deps -T toolbox lab script $(ROUTER)
