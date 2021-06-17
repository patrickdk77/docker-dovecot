.PHONY: build run sh clean help

VER = latest
NAME = dovecot
IMAGE = docker.patrickdk.com/dswett/$(NAME):$(VER)

build: ## Build the container image (default).
	docker build --pull -t $(IMAGE) .

buildx: ## Build the container image (default).
	docker buildx build --pull --platform linux/amd64,linux/arm64,linux/arm/v7 --push -t $(IMAGE) .

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

