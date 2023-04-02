# Magento Local Deployment

Magento Local Deployment is a tool that lets developers build complex Web Applications on top of Magento 2 stores.

# First Commands

```shell
# Print Help
make
```

```shell
# Deploy Magento 2
make build
```

```shell
# Print Deployment Info
make about
```

# Configuration Files

**.env** - base settings of local environment

**deploy/auth.json** - composer repository credentials

**deploy/composer.json** - building application & dependencies

**extensions** - folder to develop extensions for Magento 2

**mnt** - shared folder between local machine and containers

**mysql/mariadb.conf.d** - mysql settings

**scripts/magento/pre-install** - your custom script that sets up magento env before installation process ```make build```

**scripts/magento/setup-config-set** - your custom script that sets up magento env ```make build```

**scripts/magento/setup-install** - your custom script that sets up magento env ```make build```

**scripts/magento/post-install** - your custom script that sets up magento env after installation process ```make build```

**scripts/magento/front-build** - your script to build custom NodeJS frontend ```make build```, ```make front```

**scripts/magento/front-start** - your script to develop custom NodeJS frontend ```make dev-front```

**scripts/run-test** - your custom script, ```make test```

# How develop extensions

Run command to configure composer for your "extensions" folder
```shell
make extensions
```

# Examples

### Custom Magento SETUP:CONFIG:SET

If you have a custom installation, you can override command ```bin/magento setup:config:set ...```

Just create **scripts/magento/setup-config-set** file (see bottom) and run it ```make build```

```shell
#!/bin/bash

set -e
source .env

SETUP_CONFIG_SET="bin/magento setup:config:set \
  --db-host=$MYSQL_HOST \
  --db-name=$MYSQL_DATABASE \
  --db-user=$MYSQL_USER \
  --db-password=$MYSQL_PASSWORD \
  --session-save=redis \
  --session-save-redis-host=$REDIS_SESSION_HOST \
  --session-save-redis-port=$REDIS_SESSION_PORT \
  --session-save-redis-db=$REDIS_SESSION_DB \
  --cache-backend=redis \
  --cache-backend-redis-server=$REDIS_CACHE_HOST \
  --cache-backend-redis-port=$REDIS_CACHE_PORT \
  --cache-backend-redis-db=$REDIS_CACHE_BACKEND_DB \
  --page-cache=redis \
  --page-cache-redis-server=$REDIS_CACHE_HOST \
  --page-cache-redis-port=$REDIS_CACHE_PORT \
  --page-cache-redis-db=$REDIS_CACHE_PAGE_DB \
  --page-cache-redis-compress-data=$REDIS_COMPRESS_DATA"
    
echo -e "docker compose run --rm deploy bash -c $SETUP_CONFIG_SET"
docker compose run --rm deploy bash -c "$SETUP_CONFIG_SET"
```


### Custom Magento SETUP:INSTALL

If you have a custom installation, you can override command ```bin/magento setup:install ...```

For example, you have custom settings of OpenSearch such as ElasticSearch.<br>
Just create **scripts/magento/setup-install** file (see bottom) and run it ```make build```

```shell
#!/bin/bash

set -e
source .env

SETUP_INSTALL="bin/magento setup:install \
  --db-host=$MYSQL_HOST \
  --db-name=$MYSQL_DATABASE \
  --db-user=$MYSQL_USER \
  --db-password=$MYSQL_PASSWORD \
  --use-secure=0 \
  --use-secure-admin=1 \
  --base-url=http://$WEB_HOST/ \
  --base-url-secure=https://$WEB_HOST/ \
  --admin-user=$MAGENTO_ADMIN_USERNAME \
  --admin-password=$MAGENTO_ADMIN_PASSWORD \
  --admin-firstname=$MAGENTO_ADMIN_FIRSTNAME \
  --admin-lastname=$MAGENTO_ADMIN_LASTNAME \
  --admin-email=$MAGENTO_ADMIN_EMAIL \
  --backend-frontname=$MAGENTO_BACKEND_FRONTNAME \
  --language=$MAGENTO_LANGUAGE \
  --currency=$MAGENTO_CURRENCY \
  --timezone=$MAGENTO_TIMEZONE \
  --use-rewrites=1 \
  --search-engine=$MAGENTO_SEARCH_ENGINE \
  --elasticsearch-host=$DC_HOSTNAME_OPENSEARCH \
  --elasticsearch-port=$MAGENTO_OPENSEARCH_PORT \
  --magento-init-params=MAGE_MODE=$MAGENTO_RUN_MODE \
  --disable-modules=$MAGENTO_DISABLE_MODULES \
  --amqp-host=$RABBITMQ_HOST \
  --amqp-port=$RABBITMQ_PORT \
  --amqp-user=$RABBITMQ_USER \
  --amqp-password=$RABBITMQ_PASS \
  --amqp-virtualhost=/"

echo -e "docker compose $DC_OPTIONS run --rm deploy $SETUP_INSTALL"
docker compose $DC_OPTIONS run --rm deploy bash -c "$SETUP_INSTALL"
```


### Magento Post Installation

Just create **scripts/magento/post-install** file (see bottom) and run it ```make build```

```shell
#!/bin/bash

set -e
source .env

UPDATE_CONFIG="\
  bin/magento config:set admin/security/use_form_key 0 \
  && bin/magento config:set admin/security/session_lifetime 7776000 \
  && bin/magento config:set admin/security/lockout_failures 10000 \
  && bin/magento config:set admin/security/lockout_threshold 10000 \
  && bin/magento config:set admin/security/password_lifetime 0 \
  && bin/magento config:set admin/security/password_is_forced 0 \
  && bin/magento config:set admin/captcha/enable 0 \
  && bin/magento config:set dev/grid/async_indexing 1 \
  && bin/magento cache:enable"

echo -e "docker compose $DC_OPTIONS run --rm deploy bash -c $UPDATE_CONFIG"
docker compose $DC_OPTIONS run --rm deploy bash -c "$UPDATE_CONFIG"
```


### Custom NodeJS Frontend - Build

Just create **scripts/magento/front-build** file (see bottom) and run it ```make build```, ```make front```

```shell
#!/bin/bash

set -e
source .env

BUILD_SCANDIPWA='
unset NPM_CONFIG_PREFIX
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | dash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm current
nvm install 14.0.0

(cd ./scandipwa/ && rm -rf node_modules && npm ci)
(cd ./scandipwa/ && BUILD_MODE=magento npm run build)'

echo -e "$BUILD_SCANDIPWA"
echo -e "$BUILD_SCANDIPWA" | docker compose $DC_OPTIONS run -T --rm deploy
```


### Custom NodeJS Frontend - Development

Just create **scripts/magento/front-start** file (see bottom) and run it ```make dev-front```

```shell
#!/bin/bash

set -e
source .env

START_SCANDIPWA='
unset NPM_CONFIG_PREFIX
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | dash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm current
nvm install 14.0.0

(cd ./scandipwa/ && BUILD_MODE=magento npm run start)'

echo -e "$START_SCANDIPWA"
echo -e "$START_SCANDIPWA" | docker compose $DC_OPTIONS run -T --rm deploy
```


### Cover Test Creation

Just create **scripts/run-test** file (see bottom) and run it ```make test```

```shell
#!/bin/bash

set -e

docker compose run --rm -e XDEBUG_MODE=coverage fpm_xdebug \
  vendor/bin/phpunit -c phpunit.xml.dist ../extensions \
  --coverage-html=reports/html \
  --coverage-clover=reports/clover.coverage.xml \
  --coverage-text=reports/coverage.txt
```

### Toggle Package from Local to Public Repository

Let's say you have some local extension **"example/extension:1.0.1"**. Once you public it, to include one from public repository you can to do following:

```shell
make bash                                             # connect to container
composer remove example/extension                     # remove extension of composer
composer config --unset repositories.dev-extensions   # remove local repository
composer require example/extension:1.0.1              # add the extension from public
```
