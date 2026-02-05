.PHONY: push buildx build run sh clean help

SHORT_SHA1 := $(shell git rev-parse --short HEAD)
TAG := $(shell git describe --tags --abbrev=0)
ORIGIN := $(shell git remote get-url origin)
NAME = dovecot
PUBLIC_REPO := patrickdk/docker-dovecot
DOCKER_REPO := docker.patrickdk.com/dswett/$(NAME)
SOURCE_COMMIT_SHORT := $(SHORT_SHA1)
BUILD_DATE = $(shell date -u +'%Y-%m-%dT%H:%M:%Sz')

all: buildx

build: ## Build the container image (default).
	docker build --no-cache --pull -t $(DOCKER_REPO) .

buildx: ## Build the container image (default).
	docker buildx build --pull --platform linux/amd64,linux/arm64 --build-arg "BUILD_DATE=$(BUILD_DATE)" --build-arg "BUILD_VERSION=$(TAG)" --build-arg "BUILD_REF=$(SOURCE_COMMIT_SHORT)" --build-arg "BUILD_ORIGIN=$(ORIGIN)" --push -t $(DOCKER_REPO):$(TAG) .
	skopeo copy --all docker://$(DOCKER_REPO):$(TAG) docker://$(DOCKER_REPO):latest
	skopeo copy --all docker://$(DOCKER_REPO):$(TAG) docker://$(PUBLIC_REPO):$(TAG)
	skopeo copy --all docker://$(DOCKER_REPO):$(TAG) docker://$(PUBLIC_REPO):latest
	
	#docker buildx build --pull --platform linux/amd64,linux/arm64 --build-arg "BUILD_DATE=$(BUILD_DATE)" --build-arg "BUILD_VERSION=$(TAG)" --build-arg "BUILD_REF=$(SOURCE_COMMIT_SHORT)" --build-arg "BUILD_ORIGIN=$(ORIGIN)" --push -t $(DOCKER_REPO):latest .
	#docker buildx build --pull --platform linux/amd64,linux/arm64 --build-arg "BUILD_DATE=$(BUILD_DATE)" --build-arg "BUILD_VERSION=$(TAG)" --build-arg "BUILD_REF=$(SOURCE_COMMIT_SHORT)" --build-arg "BUILD_ORIGIN=$(ORIGIN)" --push -t $(PUBLIC_REPO):$(TAG) .
	#docker buildx build --pull --platform linux/amd64,linux/arm64 --build-arg "BUILD_DATE=$(BUILD_DATE)" --build-arg "BUILD_VERSION=$(TAG)" --build-arg "BUILD_REF=$(SOURCE_COMMIT_SHORT)" --build-arg "BUILD_ORIGIN=$(ORIGIN)" --push -t $(PUBLIC_REPO):latest .

push:
	docker push ${DOCKER_REPO}

run: ## Run a container from the image.
	docker run -d --init --name $(NAME) --read-only --restart=always $(DOCKER_REPO)

sh: ## Run a shell instead of the service for inspection, deletes the container when you leave it.
	docker run -ti --rm --init --name $(NAME) --read-only $(DOCKER_REPO) /bin/ash

clean: ## Stops and removes the running container.
	docker stop $(NAME)
	docker rm $(NAME)

help: ## Displays these usage instructions.
	@echo "Usage: make <target(s)>"
	@echo
	@echo "Specify one or multiple of the following targets and they will be processed in the given order:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "%-16s%s\n", $$1, $$2}' $(MAKEFILE_LIST)

