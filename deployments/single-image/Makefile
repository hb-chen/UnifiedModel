.DEFAULT_GOAL := help

PRACTICE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ROOT_DIR := $(abspath $(PRACTICE_DIR)/../..)
ENV_FILE ?= $(PRACTICE_DIR)/.env

.PHONY: help build run stop restart logs health compose-up compose-down compose-logs

help:
	@printf '%s\n' 'Targets:'
	@printf '  %-16s %s\n' 'build' 'Build the single UModel image'
	@printf '  %-16s %s\n' 'run' 'Run the container with docker run'
	@printf '  %-16s %s\n' 'stop' 'Stop and remove the docker-run container'
	@printf '  %-16s %s\n' 'restart' 'Stop then run'
	@printf '  %-16s %s\n' 'logs' 'Follow container logs'
	@printf '  %-16s %s\n' 'health' 'Check API and Web health endpoints'
	@printf '  %-16s %s\n' 'compose-up' 'Start with docker compose'
	@printf '  %-16s %s\n' 'compose-down' 'Stop docker compose services'
	@printf '  %-16s %s\n' 'compose-logs' 'Follow docker compose logs'

build:
	@bash "$(PRACTICE_DIR)/scripts/build.sh"

run:
	@bash "$(PRACTICE_DIR)/scripts/run.sh"

stop:
	@bash "$(PRACTICE_DIR)/scripts/stop.sh"

restart: stop run

logs:
	@bash "$(PRACTICE_DIR)/scripts/logs.sh"

health:
	@bash "$(PRACTICE_DIR)/scripts/health.sh"

compose-up:
	@docker compose --env-file "$(ENV_FILE)" -f "$(PRACTICE_DIR)/compose/docker-compose.yaml" up -d

compose-down:
	@docker compose --env-file "$(ENV_FILE)" -f "$(PRACTICE_DIR)/compose/docker-compose.yaml" down

compose-logs:
	@docker compose --env-file "$(ENV_FILE)" -f "$(PRACTICE_DIR)/compose/docker-compose.yaml" logs -f
