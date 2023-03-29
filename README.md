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

.env - base settings of local environment

deploy/auth.json - composer repository credentials

deploy/composer.json - building application & dependencies

extensions - folder to develop extensions for Magento 2

mnt - shared folder between containers

mysql/mariadb.conf.d - mysql settings

scripts/run-test - your custom script, ```make test```

# How develop extensions

Run command to configure composer for your "extensions" folder
```shell
make extensions
```
