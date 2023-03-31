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

**mnt** - shared folder between host machine and containers

**mysql/mariadb.conf.d** - mysql settings

**scripts/run-test** - your custom script, ```make test```

# How develop extensions

Run command to configure composer for your "extensions" folder
```shell
make extensions
```

# Examples

### Cover test creation

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
