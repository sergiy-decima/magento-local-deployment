normal := \033[0m
yellow := \033[33m\033[1m
green  := \033[32m\033[1m
red    := \033[31m\033[1m

include .env.dist
ifneq ($(wildcard .env),)
	include .env
endif

help:
	@echo "\n\
Usage:                         make $(yellow)<COMMANDS>$(normal)\n\
\n\
$(green)$(MAKE_TITLE)$(normal)\n\
\n\
Build:                         make build\n\
Up & Flush & Redis:            make up flush redis\n\
\n\
$(yellow)Management Commands:$(normal)\n\
  build                        Build project\n\
  up                           Create or start containers\n\
  down                         Destroy containers\n\
  start                        Start containers if they exist\n\
  stop                         Stop containers\n\
  bash                         Connect to bash\n\
  db                           Connect to database, $(yellow)up->...$(normal)\n\
  redis                        Connect to redis, $(yellow)up->...$(normal)\n\
  flush                        Flushes cache, $(yellow)up->...$(normal)\n\
\n\
$(yellow)Magento Commands:$(normal)\n\
  admin-user                   Create admin user\n\
  composer-install             Composer install\n\
  log                          Log info tracking\n\
\n\
$(yellow)Commands:$(normal)\n\
  about                        Show environment settings\n\
  extensions                   Init extension development\n\
  test                         Run custom script\n\
"

up: env
	docker compose up --detach

down: env
	docker compose down

start:
	docker compose start

stop:
	docker compose stop

bash:
	docker compose run --rm deploy bash

env:
ifeq ($(wildcard .env),)
	cp .env.dist .env
	@echo "${red}Please check \".env\" file. Set variables to start and try again if you are sure.${normal}" && false
endif

build: env add-host composer-json composer-auth mysql-config mage-work-dir composer-install mage-install db-config admin-user flush-all up about

mage-work-dir:
	mkdir -p $(MAGENTO_DIR)/bin
	(test -f $(MAGENTO_DIR)/auth.json && test -f deploy/auth.json) || cp deploy/auth.json $(MAGENTO_DIR)
	test -f $(MAGENTO_DIR)/composer.json || (test -f deploy/composer.json && cp deploy/composer.json $(MAGENTO_DIR)/composer.json)
	test -f $(MAGENTO_DIR)/composer.json || cp deploy/composer.json.sample $(MAGENTO_DIR)/composer.json
	test -f $(MAGENTO_DIR)/bin/n98 || cp deploy/bin/n98 $(MAGENTO_DIR)/bin
	test -f $(MAGENTO_DIR)/phpunit.xml.dist || cp deploy/phpunit.xml.dist $(MAGENTO_DIR)/phpunit.xml.dist

extensions: mage-work-dir
	mkdir -p $(EXTENSIONS_DIR)
	docker run --rm -e "MAGENTO_ROOT=/app" -v $(shell pwd)/$(MAGENTO_DIR):/app -v $(shell pwd)/$(EXTENSIONS_DIR):/$(EXTENSIONS_DIR) -v ~/.composer/cache:/composer/cache $(DC_IMAGE_PHP_CLI) composer config repositories.dev-extensions path ../$(EXTENSIONS_DIR)/\*
	@echo "\n\
$(green)Please use \"$(EXTENSIONS_DIR)/*\" folder to development extensions, for example:$(normal)\n\
── extensions\n\
  ├── my_extension\n\
  ├── my_extension2\n\
\n\
$(green)then, add it to composer:$(normal)\n\
> composer require example/my-extension:1.0.1\n\
"

composer-json:
	#test -f deploy/composer.json || test -f $(MAGENTO_DIR)/composer.json || cp deploy/composer.json.sample deploy/composer.json

composer-auth:
	@test -f deploy/auth.json || test -f $(MAGENTO_DIR)/auth.json || (cp deploy/auth.json.sample deploy/auth.json \
&& echo "\n${red}Please check \"deploy/auth.json\" file. Set composer credentials and try again.${normal}\n" \
&& false)

mysql-config:
	test -f mysql/mariadb.conf.d/my.cnf || echo "[client]\n\n\n[mysqld]" > mysql/mariadb.conf.d/my.cnf
	@echo "$(green)MySql configuration file \"mysql/mariadb.conf.d/my.cnf\" exists.$(normal)"

composer-install:
	docker run --rm -e "MAGENTO_ROOT=/app" -v $(shell pwd)/$(MAGENTO_DIR):/app -v $(shell pwd)/$(EXTENSIONS_DIR):/$(EXTENSIONS_DIR) -v ~/.composer/cache:/composer/cache $(DC_IMAGE_PHP_CLI) composer install --no-interaction --ansi

mage-install:
	docker compose run --rm deploy bin/magento setup:config:set \
    --db-host=$(MYSQL_HOST) \
    --db-name=$(MYSQL_DATABASE) \
    --db-user=$(MYSQL_USER) \
    --db-password=$(MYSQL_PASSWORD) \
    --session-save=redis \
    --session-save-redis-host=$(REDIS_SESSION_HOST) \
    --session-save-redis-port=$(REDIS_SESSION_PORT) \
    --session-save-redis-db=$(REDIS_SESSION_DB) \
    --cache-backend=redis \
    --cache-backend-redis-server=$(REDIS_CACHE_HOST) \
    --cache-backend-redis-port=$(REDIS_CACHE_PORT) \
    --cache-backend-redis-db=$(REDIS_CACHE_BACKEND_DB) \
    --page-cache=redis \
    --page-cache-redis-server=$(REDIS_CACHE_HOST) \
    --page-cache-redis-port=$(REDIS_CACHE_PORT) \
    --page-cache-redis-db=$(REDIS_CACHE_PAGE_DB) \
    --page-cache-redis-compress-data=$(REDIS_COMPRESS_DATA)

	docker compose run --rm deploy bin/magento setup:install \
    --db-host=$(MYSQL_HOST) \
    --db-name=$(MYSQL_DATABASE) \
    --db-user=$(MYSQL_USER) \
    --db-password=$(MYSQL_PASSWORD) \
    --use-secure=0 \
    --use-secure-admin=1 \
    --base-url=http://$(WEB_HOST)/ \
    --base-url-secure=https://$(WEB_HOST)/ \
    --admin-user=$(MAGENTO_ADMIN_USERNAME) \
    --admin-password=$(MAGENTO_ADMIN_PASSWORD) \
    --admin-firstname=$(MAGENTO_ADMIN_FIRSTNAME) \
    --admin-lastname=$(MAGENTO_ADMIN_LASTNAME) \
    --admin-email=$(MAGENTO_ADMIN_EMAIL) \
    --backend-frontname=$(MAGENTO_BACKEND_FRONTNAME) \
    --language=$(MAGENTO_LANGUAGE) \
    --currency=$(MAGENTO_CURRENCY) \
    --timezone=$(MAGENTO_TIMEZONE) \
    --use-rewrites=1 \
    --search-engine=$(MAGENTO_SEARCH_ENGINE) \
    --opensearch-host=$(DC_HOSTNAME_OPENSEARCH) \
    --opensearch-port=$(MAGENTO_OPENSEARCH_PORT) \
    --magento-init-params=MAGE_MODE=$(MAGENTO_RUN_MODE) \
    --disable-modules=$(MAGENTO_DISABLE_MODULES) \
    --amqp-host=$(RABBITMQ_HOST) \
    --amqp-port=$(RABBITMQ_PORT) \
    --amqp-user=$(RABBITMQ_USER) \
    --amqp-password=$(RABBITMQ_PASS) \
    --amqp-virtualhost=/

add-host:
	scripts/add-host $(WEB_HOST)

db-config:
	docker compose run --rm deploy bash -c "\
    bin/magento config:set admin/security/use_form_key 0 \
    && bin/magento config:set admin/security/session_lifetime 7776000 \
    && bin/magento config:set admin/security/lockout_failures 10000 \
    && bin/magento config:set admin/security/lockout_threshold 10000 \
    && bin/magento config:set admin/security/password_lifetime 0 \
    && bin/magento config:set admin/security/password_is_forced 0 \
    && bin/magento config:set admin/captcha/enable 0 \
    && bin/magento config:set dev/grid/async_indexing 1 \
    && bin/magento cache:enable"

flush:
	docker compose exec redis redis-cli -n $(REDIS_CACHE_BACKEND_DB) FLUSHDB
	docker compose exec redis redis-cli -n $(REDIS_CACHE_PAGE_DB) FLUSHDB
	@echo "$(green)Cache cleaned successfully$(normal)"

flush-all:
	docker compose exec redis redis-cli FLUSHALL
	@echo "$(green)Redis cleaned successfully$(normal)"

db:
	docker compose exec db sh -c 'mysql -u $(MYSQL_USER) -p$(MYSQL_PASSWORD) $(MYSQL_DATABASE)'

redis:
	docker compose exec redis redis-cli

admin-user:
	docker compose run --rm deploy bin/n98 admin:user:create \
    --admin-user "$(MAGENTO_ADMIN_USERNAME)" \
    --admin-password "$(MAGENTO_ADMIN_PASSWORD)" \
    --admin-email "$(MAGENTO_ADMIN_EMAIL)" \
    --admin-firstname "$(MAGENTO_ADMIN_FIRSTNAME)" \
    --admin-lastname "$(MAGENTO_ADMIN_LASTNAME)" \
    --ansi

log:
	tail -f $(MAGENTO_DIR)/var/log/*.log

test:
ifneq ($(wildcard scripts/run-test),)
	@bash scripts/run-test
else
	@echo "$(red)scripts/run-test not found. Please check file.$(normal)"
endif

about:
	@echo "\n\
🌎 Backend:       https://$(WEB_HOST)/$(MAGENTO_BACKEND_FRONTNAME)  {user: $(MAGENTO_ADMIN_USERNAME), pass: $(MAGENTO_ADMIN_PASSWORD)}\n\
📧 Email:         http://$(WEB_HOST):$(EXPOSE_MAILHOG_WEB_PORT)\n\
🩸 Redis:         http://$(WEB_HOST):$(EXPOSE_REDIS_COMMANDER_PORT)\n\
🐰 RabbitMQ:      http://$(WEB_HOST):$(EXPOSE_RABBITMQ_PORT)   {user: $(RABBITMQ_USER), pass: $(RABBITMQ_PASS)}\n\
📦 Database:      mysql://$(MYSQL_USER):$(MYSQL_PASSWORD)@localhost:$(MYSQL_EXPOSED_PORT)\n\
"
