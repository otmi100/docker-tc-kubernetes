DOCKER_IMAGE_NAME ?= docker-tc-kubernetes
.PHONY: init build test push

init:
	@which docker >/dev/null || ( echo "Error: Docker is not installed"; exit 1 )

build: init
	docker build \
		--build-arg VERSION=$$(cat .version) \
		-t ${DOCKER_IMAGE_NAME} \
		.
	docker images | grep "${DOCKER_IMAGE_NAME}"

test:
	bash test/run-tests.sh

push:
	@test -n "${DOCKER_IMAGE}" || ( echo "Error: set DOCKER_IMAGE=<registry/name:tag>"; exit 1 )
	docker tag ${DOCKER_IMAGE_NAME} ${DOCKER_IMAGE}
	docker push ${DOCKER_IMAGE}
