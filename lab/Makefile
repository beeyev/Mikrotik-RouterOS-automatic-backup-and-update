-include .docker-compose.env

#export COMPOSE_FILE=docker-compose-dev.yml
# export COMPOSE_PROJECT_NAME=dev
export DOCKER_BUILDKIT?=1
export COMPOSE_CONVERT_WINDOWS_PATHS?=1
export TZ?=UTC
export BUILD_DATE?=$(shell TZ=":UTC" date '+%Y-%m-%d %H:%M:%S (%Z)')
.EXPORT_ALL_VARIABLES:
.PHONY: *
.DEFAULT_GOAL := help

THIS_FILE := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

DOCKER_COMPOSE_COMMAND := $(shell \
	if docker compose version >/dev/null 2>&1; then echo "docker compose"; \
	elif docker-compose version >/dev/null 2>&1; then echo "docker-compose"; \
	else echo ""; fi)

ifeq ($(DOCKER_COMPOSE_COMMAND),)
  $(error "docker compose is required")
endif

help: ## Show this help
	@echo "Make Application Docker Images and Containers using Docker-Compose files in 'docker' Dir."
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m (default: help)\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

up: ## Docker compose up
	$(DOCKER_COMPOSE_COMMAND) up --build --no-deps --detach --remove-orphans

start: ## Alias for up
	$(MAKE) up

down: ## Docker compose down
	$(DOCKER_COMPOSE_COMMAND) down --remove-orphans

stop: ## Docker compose stop
	$(DOCKER_COMPOSE_COMMAND) stop

restart: ## Restart containers
	$(MAKE) down
	$(MAKE) up
	$(info Restart completed)

update: ## Update containers
	$(DOCKER_COMPOSE_COMMAND) pull
	$(MAKE) up

destroy: ## Destroy containers/volumes (keep sources app folders)
	$(MAKE) stop
	$(DOCKER_COMPOSE_COMMAND) down --rmi all --remove-orphans

rebuild: ## Rebuild docker container (destroy & upgrade)
	$(MAKE) destroy
	$(MAKE) up

state: ## Show current state
	$(DOCKER_COMPOSE_COMMAND) ps

logs: ## Show docker logs
	$(DOCKER_COMPOSE_COMMAND) logs -f --tail=100 $(ARGS)
