status:
	docker-compose ps
start:
	touch config/config.toml
	docker-compose up -d
stop:
	docker-compose down
restart:
	docker-compose restart
prune: prune-container prune-volume prune-image prune-netwok
	echo "All targes pruned"
prune-container:
	docker-compose exec -T docker  docker container prune -f
prune-volume:
	docker-compose exec -T docker  docker volume prune -f
prune-image:
	docker-compose exec -T docker  docker image prune -f
prune-network:
	docker-compose exec -T docker  docker network prune -f
