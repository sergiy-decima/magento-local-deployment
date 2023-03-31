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

**scripts/post-install** - your custom script that sets up magento env after installation process ```make build```

**scripts/run-test** - your custom script, ```make test```

# How develop extensions

Run command to configure composer for your "extensions" folder
```shell
make extensions
```

# Examples

### Magento Post Installation

Just create **scripts/post-install** (see bottom) and run it ```make build```

```shell
#!/bin/bash

set -e

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
```

### Cover Test Creation

Just create **scripts/run-test** (see bottom) and run it ```make test```

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
composer remove example/extension                     # remove extension
composer config --unset repositories.dev-extensions   # remove local repository
composer require example/extension:1.0.1              # add the extension from public
```
