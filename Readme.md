## Dockerized private gitlab-runner for the project

Simple docker-compose file which turns dockerized host into gitlab runner.


## Register

Catch all runner

```sh
register_runner.sh RUNNER_NAME REGISTER_TOKEN CI_SERVER_URL"
```

Dedicated runner that picks only tagged jobs

```sh
register_tagged_runner.sh RUNNER_NAME REGISTER_TOKEN "TAG1,TAG2" CI_SERVER_URL
```

If CI_SERVER_URL is left empty, https://gitlab.com/ci is assumed.


## Unregister

```
unregister_runner.sh RUNNER_NAME
```

## Make tasks

```
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

```
