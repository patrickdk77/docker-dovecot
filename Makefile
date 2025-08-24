.PHONY: build run sh clean help

TAG := $(shell git describe --tags --abbrev=0)
VER = latest
NAME = dovecot
IMAGE = docker.patrickdk.com/dswett/$(NAME):$(VER)
#IMAGETAG = docker.patrickdk.com/dswett/$(NAME):$(TAG)
BUILD_DATE = $(shell date -u +'%Y-%m-%dT%H:%M:%Sz')

all: buildx

build: ## Build the container image (default).
	docker build --no-cache --pull -t $(IMAGE) .

buildx: ## Build the container image (default).
	docker buildx build --pull --platform linux/amd64,linux/arm64 --build-arg "BUILD_DATE=$(BUILD_DATE)" --build-arg "BUILD_VERSION=$(TAG)" --push -t $(IMAGE) .
	#docker buildx build --pull --platform linux/amd64,linux/arm64 --build-arg "BUILD_DATE=$(BUILD_DATE)" --build-arg "BUILD_VERSION=$(TAG)" --push -t $(IMAGETAG) .

push:
	docker push ${IMAGE}

run: ## Run a container from the image.
	docker run -d --init --name $(NAME) --read-only --restart=always $(IMAGE)

sh: ## Run a shell instead of the service for inspection, deletes the container when you leave it.
	docker run -ti --rm --init --name $(NAME) --read-only $(IMAGE) /bin/ash

clean: ## Stops and removes the running container.
	docker stop $(NAME)
	docker rm $(NAME)

help: ## Displays these usage instructions.
	@echo "Usage: make <target(s)>"
	@echo
	@echo "Specify one or multiple of the following targets and they will be processed in the given order:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "%-16s%s\n", $$1, $$2}' $(MAKEFILE_LIST)

