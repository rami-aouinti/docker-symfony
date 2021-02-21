DOCKER_COMPOSE = docker-compose
EXEC = $(DOCKER_COMPOSE) exec
EXEC_PHP = $(DOCKER_COMPOSE) exec php
RUN_PHP = $(DOCKER_COMPOSE) run --rm php74-service php
RUN_NODE = $(DOCKER_COMPOSE) run --rm node-service yarn
EXEC_NODE = $(DOCKER_COMPOSE) exec node
SYMFONY = $(RUN_PHP) bin/console
COMPOSER = $(EXEC_PHP) composer

build:
	$(DOCKER_COMPOSE) pull --parallel --quiet --ignore-pull-failures 2> /dev/null
	$(DOCKER_COMPOSE) build --pull

kill:
	$(DOCKER_COMPOSE) kill
	$(DOCKER_COMPOSE) down --volumes --remove-orphans

install: ## Install and start the project
install: start db npm

reset: ## Stop and start a fresh install of the project
reset: kill install

start: ## Start the project
	$(DOCKER_COMPOSE) up -d --remove-orphans --no-recreate

stop: ## Stop the project
	$(DOCKER_COMPOSE) stop

no-docker:
	$(eval DOCKER_COMPOSE := \#)
	$(eval EXEC_PHP := )
	$(eval EXEC_JS := )

.PHONY: build kill install reset start stop no-docker

##
## Utils
## -----
##

vendor: ## Composer update
vendor:
		composer update

db: ## Reset the database and load fixtures
db: 
	$(SYMFONY) doctrine:database:drop --if-exists --force
	$(SYMFONY) doctrine:database:create --if-not-exists
	$(SYMFONY) doctrine:migrations:migrate --no-interaction --allow-no-migration
	$(SYMFONY) doctrine:fixtures:load --no-interaction
	
migration: ## Generate a new doctrine migration
migration: 
	$(SYMFONY) doctrine:migrations:diff
	$(SYMFONY) doctrine:migrations:migrate --no-interaction --allow-no-migration


db-validate-schema: ## Validate the doctrine ORM mapping
db-validate-schema: 
	$(SYMFONY) doctrine:schema:validate

.PHONY: db migration watch	
	

npm: ## NPM INSTALL
	$(RUN_NODE) install


ci: ## Run all quality insurance checks (tests, code styles, linting, security, static analysis...)
#ci: php-cs-fixer phpcs phpmd phpmnd phpstan psalm lint validate-composer validate-mapping security test test-coverage test-spec
ci: php-cs-fixer phpcs phpmd phpstan psalm lint validate-composer validate-mapping security test test-coverage test-spec

ci.local: ## Run quality insurance checks from inside the php container
ci.local: no-docker ci

lint: ## Run lint check
lint:
	$(SYMFONY) lint:yaml config/ --parse-tags
	$(SYMFONY) lint:yaml fixtures/
	$(SYMFONY) lint:yaml translations/
	$(SYMFONY) lint:container

phpcs: ## Run phpcode_sniffer
phpcs:
	vendor/bin/phpcs

php-cs-fixer: ## Run PHP-CS-FIXER
php-cs-fixer:
	$(EXEC) vendor/bin/php-cs-fixer fix --verbose

php-cs-fixer.dry-run: ## Run php-cs-fixer in dry-run mode
php-cs-fixer.dry-run:
	vendor/bin/php-cs-fixer fix --verbose --diff --dry-run

phpmd: ## Run PHPMD
phpmd:
	vendor/bin/phpmd src/,tests/ text phpmd.xml.dist

#phpmnd: ## Run PHPMND
#phpmnd:
#	$(EXEC_PHP) vendor/bin/phpmnd src --extensions=default_parameter

phpstan: ## Run PHPSTAN
phpstan:
	vendor/bin/phpstan analyse
	
rector.dry: ## Dry-run rector
rector.dry:
	vendor/bin/rector process --dry-run
	
rector: ## Run RECTOR
rector:
	vendor/bin/rector process
	
psalm: ## Run PSALM
psalm:
	vendor/bin/psalm

security: ## Run security-checker
security:
	bin/security-checker

test: ## Run phpunit tests
test:
	vendor/bin/phpunit

test-coverage: ## Run phpunit tests with code coverage (phpdbg)
test-coverage: test-coverage-pcov

test-coverage-phpdbg: ## Run phpunit tests with code coverage (phpdbg)
test-coverage-phpdbg:
	phpdbg -qrr ./vendor/bin/phpunit --coverage-html=var/coverage

test-coverage-pcov: ## Run phpunit tests with code coverage (pcov - uncomment extension in dockerfile)
test-coverage-pcov:
	vendor/bin/phpunit --coverage-html=var/coverage

test-coverage-xdebug: ## Run phpunit tests with code coverage (xdebug - uncomment extension in dockerfile)
test-coverage-xdebug:
	vendor/bin/phpunit --coverage-html=var/coverage

test-coverage-xdebug-filter: ## Run phpunit tests with code coverage (xdebug with filter - uncomment extension in dockerfile)
test-coverage-xdebug-filter:
	vendor/bin/phpunit --dump-xdebug-filter var/xdebug-filter.php
	vendor/bin/phpunit --prepend var/xdebug-filter.php --coverage-html=var/coverage

validate-composer: ## Validate composer.json and composer.lock
validate-composer:
	composer validate
	composer normalize --dry-run

validate-mapping: ## Validate doctrine mapping
validate-mapping:
	$(SYMFONY) doctrine:schema:validate --skip-sync -vvv --no-interaction
