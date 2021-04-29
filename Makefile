# Adheres to [Semantic Versioning](https://semver.org)
VERSION := 1.0.0-dev

IMAGE := git-ssh
SERVICE := git-ssh
USER := git

BUILD_CONTEXT := .
DOCKERFILE := $(BUILD_CONTEXT)/Dockerfile
DOCKERCOMPFILE := $(BUILD_CONTEXT)/docker-compose.yml

.PHONY: help tag run-shell up start stop down destroy restart ps log \
	login-shell login-shell-root new-repo fix-repos clean

# Default target
help:
	@echo "Available targets:"
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null \
	| awk -v RS= -F: '/^# File/,/^# Finished Make data base/ \
		{if ($$1 !~ "^[#.]") {print $$1}}' \
       	| sort \
	| egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

build: git-shell-commands Dockerfile .dockerignore fix-repos.sh sshd_config \
	start.sh
	@echo "Dummy time stamp file for Make to determine when to rebuild" > $@
	sudo docker build -t $(IMAGE):$(VERSION) $(BUILD_CONTEXT)/ \
		-f $(DOCKERFILE)
	sudo docker image tag $(IMAGE):$(VERSION) $(IMAGE):latest

tag: 
# If variable `t` is not defined, use `$(VERSION)`
ifeq ($(origin t),undefined)
	@echo "Make:  No tag provided, \`$(VERSION)\` is used as default."
	@echo "Make:      You can provide a custom tag via variable \`t\`"
	@echo "Make:      (\`make tag t=<TAG>\`)."
	sudo docker image tag $(IMAGE):latest $(IMAGE):$(VERSION)
else
	sudo docker image tag $(IMAGE):latest $(IMAGE):$(t)
endif

prepare-deploy: build
	@echo "Dummy time stamp file for Make to determine when to rebuild" > $@
	mkdir -p $(BUILD_CONTEXT)/$(SERVICE)/keys-host/
	mkdir -p $(BUILD_CONTEXT)/$(SERVICE)/keys/
	mkdir -p $(BUILD_CONTEXT)/$(SERVICE)/repos/
# If `docker-compose.yml` does not exist, copy the template
ifeq (,$(wildcard $(DOCKERCOMPFILE)))
	cp $(DOCKERCOMPFILE).example $(DOCKERCOMPFILE)
endif
	@echo "Makefile:  Customize configuration file \`$(DOCKERCOMPFILE)\`"
	@echo "Makefile:      and then deploy (using \`make deploy\`)."

run-shell:
	sudo docker-compose run $(SERVICE) ash

deploy:	up
up:
	sudo docker-compose -f $(DOCKERCOMPFILE) up -d

start:
	sudo docker-compose -f $(DOCKERCOMPFILE) start

stop:
	sudo docker-compose -f $(DOCKERCOMPFILE) stop -t 1

down:
	sudo docker-compose -f $(DOCKERCOMPFILE) down -t 1

destroy:
	sudo docker-compose -f $(DOCKERCOMPFILE) down -t 1 -v

restart:
	sudo docker-compose -f $(DOCKERCOMPFILE) stop -t 1
	sudo docker-compose -f $(DOCKERCOMPFILE) up -d

ps:
	sudo docker-compose -f $(DOCKERCOMPFILE) ps

log:
	sudo docker logs -t -f $(SERVICE)

login-shell:
	sudo docker-compose -f $(DOCKERCOMPFILE) exec -u $(USER) $(SERVICE) ash

login-shell-root:
	sudo docker-compose -f $(DOCKERCOMPFILE) exec $(SERVICE) ash

new-repo:
# Only continue if variable `r` is defined
ifeq ($(origin r),undefined)
	@echo "Make:  Please provide a repository name via variable \`r\`"
	@echo "Make:      (\`make new-repo r=<REPO_NAME>\`)."
else
	sudo docker-compose -f $(DOCKERCOMPFILE) exec -u $(USER) $(SERVICE) \
		git init --bare ./repos/$(r).git
endif

fix-repos:
	sudo docker-compose -f $(DOCKERCOMPFILE) exec $(SERVICE) ./fix-repos.sh

clean:
	rm -rf \
		$(BUILD_CONTEXT)/build \
		$(BUILD_CONTEXT)/prepare-deploy
# Confirm before removal since data might be deleted
	@echo "Make:  !CAUTION!  The following will delete the configuration"
	@echo "Make:      file \`$(DOCKERCOMPFILE)\` and the directory"
	@echo "Make:      \`$(BUILD_CONTEXT)/$(SERVICE)/\` where all data is"
	@echo "Make:      stored.  Please confirm."
	rm -rI \
		$(DOCKERCOMPFILE) \
		$(BUILD_CONTEXT)/$(SERVICE)/
