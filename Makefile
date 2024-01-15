GO ?= go
GOFMT ?= $(GO)fmt
FIRST_GOPATH := $(firstword $(subst :, ,$(shell $(GO) env GOPATH)))
GOOPTS ?=
GOOS ?= $(shell $(GO) env GOHOSTOS)
GOARCH ?= $(shell $(GO) env GOHOSTARCH)

IMAGE_NAME ?= pando85/transcoder
IMAGE_VERSION ?= latest

.DEFAULT: help
.PHONY: help
help:	## show this help menu.
	@echo "Usage: make [TARGET ...]"
	@echo ""
	@@egrep -h "#[#]" $(MAKEFILE_LIST) | sed -e 's/\\$$//' | awk 'BEGIN {FS = "[:=].*?#[#] "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

.PHONY: build-all
build-all: server worker
build-all:	## build all binaries

.PHONY: server
server: build-server
server:		## build server binary

.PHONY: worker
worker: build-worker
worker:		## build worker binary

.PHONY: build-%
build-%:
	@echo "Building dist/transcoder-$*"
	@CGO_ENABLED=0 go build -o dist/transcoder-$* $*/main.go

.PHONY: images
images: image-server image-worker
images:		## build container images

.PHONY: images
push-images: push-image-server push-image-worker
push-images:		## build and push container images

.PHONY: image-%
.PHONY: push-image-%
image-% push-image-%: build-%
	@export DOCKER_BUILD_ARG="--cache-to type=inline $(if $(findstring push,$@),--push,--load)"; \
	docker buildx build \
		$${DOCKER_BUILD_ARG} \
		-t $(IMAGE_NAME):$(IMAGE_VERSION)-$* \
		-f Dockerfile \
		--target $* \
		. ; \
	if [ "$*" = "worker" ]; then \
		docker buildx build \
		$${DOCKER_BUILD_ARG} \
		-t $(IMAGE_NAME):$(IMAGE_VERSION)-$*-pgs \
		--target worker-pgs \
		-f Dockerfile \
		. ; \
	fi;

MAX_ATTEMPTS ?= 10

.PHONY: run-all
run-all: images
run-all:	## run all services in local using docker-compose
run-all:
	@scripts/run-all.sh

.PHONY: down
down:		## stop all containers from docker-compose
down:
	@docker-compose down

.PHONY: logs
logs:	## show logs
logs:
	@docker-compose logs -f

.PHONY: demo-files
demo-files:		## download demo file
demo-files:
	@scripts/get-demo-files.sh

.PHONY: test-upload
test-upload:	## upload job to test all process
test-upload: demo-files run-all
	@scripts/test-upload.sh
