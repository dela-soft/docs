COMPOSE := docker compose

up:
	@$(COMPOSE) up -d

pull:
	@$(COMPOSE) pull
	@$(COMPOSE) up -d

down:
	@$(COMPOSE) down

logs:
	@$(COMPOSE) logs -f --tail 100

.PHONY: up pull down logs
