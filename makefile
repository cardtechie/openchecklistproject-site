up:
	#export $(shell sed 's/=.*//' .env)
	docker-compose pull
	docker-compose build --build-arg COMPOSER_TOKEN=${COMPOSER_TOKEN}
	docker-compose up

upd:
	#export $(shell sed 's/=.*//' .env)
	docker-compose pull
	docker-compose build --build-arg COMPOSER_TOKEN=${COMPOSER_TOKEN}
	docker-compose up -d

down:
	docker-compose down

clean-docker:
	docker system prune -af --volumes

test:
	docker-compose -f .docker/tests.docker-compose.yaml run tcapi npm test

test-local:
	docker-compose -f .docker/tests.docker-compose.yaml -f .docker/local.tests.docker-compose.yaml run tcapi npm test

github-build: down clean-docker upd test
