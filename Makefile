normal := \033[0m
yellow := \033[33m\033[1m
green  := \033[32m\033[1m
red    := \033[31m\033[1m
cyan   := \033[36m\033[1m

include .env.dist
ifneq ($(wildcard .env),)
	include .env
endif

DC_OPTIONS := $(shell echo $(DC_OPTIONS))

help:
	@echo "\n\
Usage:                         make $(yellow)<COMMANDS>$(normal)\n\
\n\
$(green)$(MAKE_HELP_TITLE)$(normal)\n\
\n\
Build:                         make build\n\
Up & Flush & Front:            make up flush $(cyan)dev-front$(normal)\n\
\n\
$(yellow)Management Commands:$(normal)\n\
  build                        Build project\n\
  up                           Create or start containers\n\
  down                         Destroy containers, cache, session\n\
  start                        Start containers if they exist\n\
  stop                         Stop containers\n\
  status                       Status of containers\n\
  bash                         Connect to bash\n\
  db                           Connect to database, $(yellow)up->...$(normal)\n\
  redis                        Connect to redis, $(yellow)up->...$(normal)\n\
  flush                        Flushes cache, $(yellow)up->...$(normal)\n\
  prepare                      Prepare configuration files before building\n\
  rebuild                      Reset all data and build everything\n\
  xdebash                      Connect to bash with xdebug\n\
\n\
$(yellow)Magento Commands:$(normal)\n\
  $(cyan)front$(normal)                        Build $(cyan)custom$(normal) NodeJS frontend\n\
  $(cyan)dev-front$(normal)                    Develop $(cyan)custom$(normal) NodeJS frontend\n\
  admin-user                   Create admin user\n\
  composer-install             Composer install\n\
  log                          Log info tracking\n\
  mysqldump                    Create database dump\n\
\n\
$(yellow)Commands:$(normal)\n\
  about                        Show short info about environment\n\
  extensions                   Init extension development\n\
  $(cyan)test$(normal)                         Run $(cyan)custom$(normal) script\n\
"

up: env
	docker compose $(DC_OPTIONS) up --detach

down: env
	docker compose $(DC_OPTIONS) down

start:
	docker compose $(DC_OPTIONS) start

stop:
	docker compose $(DC_OPTIONS) stop

status: env
	docker compose $(DC_OPTIONS) ps

bash: env
	docker compose $(DC_OPTIONS) run --rm deploy bash

xdebash: env
	docker compose $(DC_OPTIONS) run --rm fpm_xdebug bash

env:
ifeq ($(wildcard .env),)
	cp .env.dist .env
	@echo "${red}Please check \".env\" file. Set variables to start and try again if you are sure.${normal}" && false
endif
	@mkdir -p $(SHARED_DIR)

rebuild: reset build

reset: reset-db reset-env

reset-db: down
	docker volume rm -f $(COMPOSE_PROJECT_NAME)_db-data

reset-env:
	test -f $(MAGENTO_DIR)/app/etc/env.php && mv -f $(MAGENTO_DIR)/app/etc/env.php $(MAGENTO_DIR)/app/etc/env.old.php

build: env add-host composer-json composer-auth mysql-config mage-work-dir composer-install mage-install admin-user flush-all up about

prepare:
	@mkdir -p $(MAGENTO_DIR)
	@mkdir -p $(SHARED_DIR)
	@mkdir -p scripts/magento
	@test -f .env || cp .env.dist .env
	@test -f deploy/auth.json || cp deploy/auth.json.sample deploy/auth.json
	@test -f deploy/composer.json || cp deploy/composer.json.sample deploy/composer.json
	@test -f mysql/mariadb.conf.d/my.cnf || echo "[client]\n\n\n[mysqld]" > mysql/mariadb.conf.d/my.cnf

	@echo "${green}Please check files:\n\
- .env\n\
- deploy/auth.json\n\
- deploy/composer.json\n\
- mysql/mariadb.conf.d/my.cnf\
${normal}"

mage-work-dir:
	mkdir -p $(MAGENTO_DIR)/bin
	test -f $(MAGENTO_DIR)/auth.json || (test -f deploy/auth.json && cp deploy/auth.json $(MAGENTO_DIR)) || true
	test -f $(MAGENTO_DIR)/composer.json || (test -f deploy/composer.json && cp deploy/composer.json $(MAGENTO_DIR)/composer.json || true)
	test -f $(MAGENTO_DIR)/composer.json || cp deploy/composer.json.sample $(MAGENTO_DIR)/composer.json
	test -f $(MAGENTO_DIR)/bin/n98 || cp deploy/bin/n98 $(MAGENTO_DIR)/bin

extensions: mage-work-dir
	mkdir -p $(EXTENSIONS_DIR)
	docker run --rm -e "MAGENTO_ROOT=$(MAGENTO_ROOT)" -v $(shell pwd)/$(MAGENTO_DIR):$(MAGENTO_ROOT) -v $(shell pwd)/$(EXTENSIONS_DIR):/$(EXTENSIONS_DIR) -v ~/.composer/cache:/composer/cache magento/magento-cloud-docker-php:$(DC_IMAGE_PHP_CLI_TAG) composer config repositories.dev-extensions path ../$(EXTENSIONS_DIR)/\*
	@echo "\n\
$(green)Please use \"$(EXTENSIONS_DIR)/*\" folder to develop extensions, for example:$(normal)\n\
── extensions\n\
  ├── my_extension\n\
  ├── my_extension2\n\
\n\
$(green)then using docker container, add it to composer:$(normal)\n\
> make bash\n\
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
	docker run --rm -e "MAGENTO_ROOT=$(MAGENTO_ROOT)" -v $(shell pwd)/$(MAGENTO_DIR):$(MAGENTO_ROOT) -v $(shell pwd)/$(EXTENSIONS_DIR):/$(EXTENSIONS_DIR) -v ~/.composer/cache:/composer/cache magento/magento-cloud-docker-php:$(DC_IMAGE_PHP_CLI_TAG) composer install --no-interaction --ansi --prefer-dist --no-suggest

mage-install: mage-pre-install mage-setup-configuration mage-post-install front

mage-pre-install:
ifneq ($(wildcard scripts/magento/pre-install),)
	bash scripts/magento/pre-install
endif

mage-setup-configuration:
ifneq ($(wildcard scripts/magento/setup-config-set),)
	bash scripts/magento/setup-config-set
else
	docker compose $(DC_OPTIONS) run --rm deploy bin/magento setup:config:set \
    --db-host=$(MYSQL_HOST) \
    --db-name=$(MYSQL_DATABASE) \
    --db-user=$(MYSQL_USER) \
    --db-password=$(MYSQL_PASSWORD) \
    --session-save=redis \
    --session-save-redis-host=$(REDIS_SESSION_HOST) \
    --session-save-redis-port=6379 \
    --session-save-redis-db=$(REDIS_SESSION_DB) \
    --cache-backend=redis \
    --cache-backend-redis-server=$(REDIS_CACHE_HOST) \
    --cache-backend-redis-port=6379 \
    --cache-backend-redis-db=$(REDIS_CACHE_BACKEND_DB) \
    --page-cache=redis \
    --page-cache-redis-server=$(REDIS_CACHE_HOST) \
    --page-cache-redis-port=6379 \
    --page-cache-redis-db=$(REDIS_CACHE_PAGE_DB) \
    --page-cache-redis-compress-data=$(REDIS_COMPRESS_DATA)
endif

ifneq ($(wildcard scripts/magento/setup-install),)
	bash scripts/magento/setup-install
else
	docker compose $(DC_OPTIONS) run --rm deploy bin/magento setup:install \
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
endif

mage-post-install:
ifneq ($(wildcard scripts/magento/post-install),)
	bash scripts/magento/post-install
else
	docker compose $(DC_OPTIONS) run --rm deploy bash -c "\
    bin/magento config:set admin/security/use_form_key 0 \
    && bin/magento config:set admin/security/session_lifetime 7776000 \
    && bin/magento config:set admin/security/lockout_failures 10000 \
    && bin/magento config:set admin/security/lockout_threshold 10000 \
    && bin/magento config:set admin/security/password_lifetime 0 \
    && bin/magento config:set admin/security/password_is_forced 0 \
    && bin/magento config:set admin/captcha/enable 0 \
    && bin/magento config:set dev/grid/async_indexing 1 \
    && bin/magento cache:enable"
endif

add-host:
	scripts/add-host $(WEB_HOST)

flush:
	docker compose $(DC_OPTIONS) exec redis redis-cli -n $(REDIS_CACHE_BACKEND_DB) FLUSHDB
	docker compose $(DC_OPTIONS) exec redis redis-cli -n $(REDIS_CACHE_PAGE_DB) FLUSHDB
	@echo "$(green)Cache cleaned successfully$(normal)"

flush-all:
	docker compose $(DC_OPTIONS) exec redis redis-cli FLUSHALL
	@echo "$(green)Redis cleaned successfully$(normal)"

db:
	docker compose $(DC_OPTIONS) exec db sh -c 'mysql -u $(MYSQL_USER) -p$(MYSQL_PASSWORD) $(MYSQL_DATABASE)'

redis:
	docker compose $(DC_OPTIONS) exec redis redis-cli

admin-user:
	docker compose $(DC_OPTIONS) run --rm deploy bin/n98 admin:user:create \
    --admin-user "$(MAGENTO_ADMIN_USERNAME)" \
    --admin-password "$(MAGENTO_ADMIN_PASSWORD)" \
    --admin-email "$(MAGENTO_ADMIN_EMAIL)" \
    --admin-firstname "$(MAGENTO_ADMIN_FIRSTNAME)" \
    --admin-lastname "$(MAGENTO_ADMIN_LASTNAME)" \
    --ansi

log:
	tail -f $(MAGENTO_DIR)/var/log/*.log

mysqldump:
	$(eval DUMP_DATE=$(shell date +'%y%m%d%H%M%S'))
	mkdir -p mysql/dumps
	bin/mysqldump > mysql/dumps/magento.dump-$(DUMP_DATE).sql
	@echo "\n$(green)Dump was created: mysql/dumps/magento.dump-$(DUMP_DATE).sql$(normal)\n"

test:
	test -f $(MAGENTO_DIR)/dev/tests/integration/etc/config-global.php || (test -f phpunit/etc/config-global.php && cp phpunit/etc/config-global.php $(MAGENTO_DIR)/dev/tests/integration/etc/config-global.php || cp phpunit/etc/config-global.php.dist $(MAGENTO_DIR)/dev/tests/integration/etc/config-global.php)
	test -f $(MAGENTO_DIR)/dev/tests/integration/etc/install-config-mysql.php || (test -f phpunit/etc/install-config-mysql.php && cp phpunit/etc/install-config-mysql.php $(MAGENTO_DIR)/dev/tests/integration/etc/install-config-mysql.php || cp phpunit/etc/install-config-mysql.php.dist $(MAGENTO_DIR)/dev/tests/integration/etc/install-config-mysql.php)
	test -f $(MAGENTO_DIR)/phpunit.xml.dist || cp phpunit/phpunit.xml.dist $(MAGENTO_DIR)/phpunit.xml.dist
ifneq ($(wildcard scripts/run-test),)
	bash scripts/run-test || true
else
	@echo "$(red)scripts/run-test not found. Please check file.$(normal)"
endif

front:
ifneq ($(wildcard scripts/magento/front-build),)
	bash scripts/magento/front-build
else
	@echo "If you have custom NodeJS frontend, you can create bash scenario \"scripts/magento/front-build\" to deploy it"
endif

dev-front:
ifneq ($(wildcard scripts/magento/front-start),)
	bash scripts/magento/front-start
else
	@echo "If you have custom NodeJS frontend, you can create bash scenario \"scripts/magento/front-start\" to develop it"
endif

about:
	@echo "\n\
🌎 Backend:           https://$(WEB_HOST)/$(MAGENTO_BACKEND_FRONTNAME)\n\
   ├ user             $(MAGENTO_ADMIN_USERNAME)\n\
   └ pass             $(MAGENTO_ADMIN_PASSWORD)\n\
📦 Database (demo):   mysql://$(MYSQL_USER):$(MYSQL_PASSWORD)@localhost:$(EXPOSE_MYSQL_PORT)\n\
📦 Database (test):   mysql://$(TEST_MYSQL_USER):$(TEST_MYSQL_PASSWORD)@localhost:$(EXPOSE_TEST_MYSQL_PORT)\n\
📧 Email:             http://$(WEB_HOST):$(EXPOSE_MAILHOG_WEB_PORT)\n\
🐰 RabbitMQ:          http://$(WEB_HOST):$(EXPOSE_RABBITMQ_PORT)\n\
   ├ user             $(RABBITMQ_USER)\n\
   └ pass             $(RABBITMQ_PASS)\n\
🩸 Redis:             http://$(WEB_HOST):$(EXPOSE_REDIS_COMMANDER_PORT)\n\
   ├ cache-backend    redis://$(REDIS_CACHE_BACKEND_DB)@localhost:$(EXPOSE_REDIS_CACHE_PORT)\n\
   ├ page-cache       redis://$(REDIS_CACHE_PAGE_DB)@localhost:$(EXPOSE_REDIS_CACHE_PORT)\n\
   └ session          redis://$(REDIS_SESSION_DB)@localhost:$(EXPOSE_REDIS_SESSION_PORT)\n\
"

.PHONY: help up down start stop status bash xdebash env build rebuild reset reset-db reset-env prepare mage-work-dir extensions composer-json composer-auth mysql-config composer-install mage-install mage-pre-install mage-setup-configuration mage-post-install front dev-front add-host flush flush-all db redis admin-user log mysqldump test about
