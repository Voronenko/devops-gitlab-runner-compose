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


## Define `image` in the `.gitlab-ci.yml` file

You can define an image that's used for all jobs, and a list of
services that you want to use during runtime:

```yaml
default:
  image: ruby:2.6
  services:
    - postgres:11.7
  before_script:
    - bundle install
test:
  script:
    - bundle exec rake spec
```

The image name must be in one of the following formats:

- `image: <image-name>` (Same as using `<image-name>` with the `latest` tag)
- `image: <image-name>:<tag>`
- `image: <image-name>@<digest>`

## Extended Docker configuration options

> Introduced in GitLab and GitLab Runner 9.4.
You can use a string or a map for the `image` or `services` entries:

- Strings must include the full image name
  (including the registry, if you want to download the image from a registry
  other than Docker Hub).
- Maps must contain at least the `name` option,
  which is the same image name as used for the string setting.

For example, the following two definitions are equal:

- A string for `image` and `services`:

  ```yaml
  image: "registry.example.com/my/image:latest"
  services:
    - postgresql:14.3
    - redis:latest
  ```

- A map for `image` and `services`. The `image:name` is
  required:

  ```yaml
  image:
    name: "registry.example.com/my/image:latest"
  services:
    - name: postgresql:14.3
    - name: redis:latest
  ```

## Where scripts are executed

When a CI job runs in a Docker container, the `before_script`, `script`, and `after_script` commands run in the `/builds/<project-path>/` directory. Your image may have a different default `WORKDIR` defined. To move to your `WORKDIR`, save the `WORKDIR` as an environment variable so you can reference it in the container during the job's runtime.

### Override the entrypoint of an image

> Introduced in GitLab and GitLab Runner 9.4. Read more about the [extended configuration options](../docker/using_docker_images.md#extended-docker-configuration-options).
Before explaining the available entrypoint override methods, let's describe
how the runner starts. It uses a Docker image for the containers used in the
CI/CD jobs:

1. The runner starts a Docker container using the defined entrypoint. The default
   from `Dockerfile` that may be overridden in the `.gitlab-ci.yml` file.
1. The runner attaches itself to a running container.
1. The runner prepares a script (the combination of
   [`before_script`](../yaml/index.md#before_script),
   [`script`](../yaml/index.md#script),
   and [`after_script`](../yaml/index.md#after_script)).
1. The runner sends the script to the container's shell `stdin` and receives the
   output.

To override the entrypoint of a Docker image,
define an empty `entrypoint` in the `.gitlab-ci.yml` file, so the runner does not start
a useless shell layer. However, that does not work for all Docker versions.

- For Docker 17.06 and later, the `entrypoint` can be set to an empty value.
- For Docker 17.03 and earlier, the `entrypoint` can be set to
  `/bin/sh -c`, `/bin/bash -c`, or an equivalent shell available in the image.

The syntax of `image:entrypoint` is similar to [Dockerfile's `ENTRYPOINT`](https://docs.docker.com/engine/reference/builder/#entrypoint).

Let's assume you have a `super/sql:experimental` image with a SQL database
in it. You want to use it as a base image for your job because you
want to execute some tests with this database binary. Let's also assume that
this image is configured with `/usr/bin/super-sql run` as an entrypoint. When
the container starts without additional options, it runs
the database's process. The runner expects that the image has no
entrypoint or that the entrypoint is prepared to start a shell command.

With the extended Docker configuration options, instead of:

- Creating your own image based on `super/sql:experimental`.
- Setting the `ENTRYPOINT` to a shell.
- Using the new image in your CI job.

You can now define an `entrypoint` in the `.gitlab-ci.yml` file.

**For Docker 17.06 and later:**

```yaml
image:
  name: super/sql:experimental
  entrypoint: [""]
```

**For Docker 17.03 and earlier:**

```yaml
image:
  name: super/sql:experimental
  entrypoint: ["/bin/sh", "-c"]
```

## Define image and services in `config.toml`

Look for the `[runners.docker]` section:

```toml
[runners.docker]
  image = "ruby:latest"
  services = ["mysql:latest", "postgres:latest"]
```

The image and services defined this way are added to all jobs run by
that runner.

## Access an image from a private Container Registry

To access private container registries, the GitLab Runner process can use:

- [Statically defined credentials](#use-statically-defined-credentials). That is, a username and password for a specific registry.
- [Credentials Store](#use-a-credentials-store). For more information, see [the relevant Docker documentation](https://docs.docker.com/engine/reference/commandline/login/#credentials-store).
- [Credential Helpers](#use-credential-helpers). For more information, see [the relevant Docker documentation](https://docs.docker.com/engine/reference/commandline/login/#credential-helpers).

To define which option should be used, the runner process reads the configuration in this order:

- A `DOCKER_AUTH_CONFIG` [CI/CD variable](../variables/index.md).
- A `DOCKER_AUTH_CONFIG` environment variable set in the runner's `config.toml` file.
- A `config.json` file in `$HOME/.docker` directory of the user running the process.
  If the `--user` flag is provided to run the child processes as unprivileged user,
  the home directory of the main runner process user is used.

### Requirements and limitations

- Available for [Kubernetes executor](https://docs.gitlab.com/runner/executors/kubernetes.html)
  in GitLab Runner 13.1 and later.
- [Credentials Store](#use-a-credentials-store) and [Credential Helpers](#use-credential-helpers)
  require binaries to be added to the GitLab Runner `$PATH`, and require access to do so. Therefore,
  these features are not available on shared runners, or any other runner where the user does not
  have access to the environment where the runner is installed.

### Use statically-defined credentials

There are two approaches that you can take to access a
private registry. Both require setting the CI/CD variable
`DOCKER_AUTH_CONFIG` with appropriate authentication information.

1. Per-job: To configure one job to access a private registry, add
   `DOCKER_AUTH_CONFIG` as a [CI/CD variable](../variables/index.md).
1. Per-runner: To configure a runner so all its jobs can access a
   private registry, add `DOCKER_AUTH_CONFIG` as an environment variable in the
   runner's configuration.

See below for examples of each.

#### Determine your `DOCKER_AUTH_CONFIG` data

As an example, let's assume you want to use the `registry.example.com:5000/private/image:latest`
image. This image is private and requires you to sign in to a private container
registry.

Let's also assume that these are the sign-in credentials:

| Key      | Value                       |
|:---------|:----------------------------|
| registry | `registry.example.com:5000` |
| username | `my_username`               |
| password | `my_password`               |

Use one of the following methods to determine the value for `DOCKER_AUTH_CONFIG`:

- Do a `docker login` on your local machine:

  ```shell
  docker login registry.example.com:5000 --username my_username --password my_password
  ```

  Then copy the content of `~/.docker/config.json`.

  If you don't need access to the registry from your computer, you
  can do a `docker logout`:

  ```shell
  docker logout registry.example.com:5000
  ```

- In some setups, it's possible the Docker client uses the available system key
  store to store the result of `docker login`. In that case, it's impossible to
  read `~/.docker/config.json`, so you must prepare the required
  base64-encoded version of `${username}:${password}` and create the Docker
  configuration JSON manually. Open a terminal and execute the following command:

  ```shell
  # The use of printf (as opposed to echo) prevents encoding a newline in the password.
  printf "my_username:my_password" | openssl base64 -A
  # Example output to copy
  bXlfdXNlcm5hbWU6bXlfcGFzc3dvcmQ=
  ```

  Create the Docker JSON configuration content as follows:

  ```json
  {
      "auths": {
          "registry.example.com:5000": {
              "auth": "(Base64 content from above)"
          }
      }
  }
  ```

#### Configure a job

To configure a single job with access for `registry.example.com:5000`,
follow these steps:

1. Create a [CI/CD variable](../variables/index.md) `DOCKER_AUTH_CONFIG` with the content of the
   Docker configuration file as the value:

   ```json
   {
       "auths": {
           "registry.example.com:5000": {
               "auth": "bXlfdXNlcm5hbWU6bXlfcGFzc3dvcmQ="
           }
       }
   }
   ```

1. You can now use any private image from `registry.example.com:5000` defined in
   `image` or `services` in your `.gitlab-ci.yml` file:

   ```yaml
   image: registry.example.com:5000/namespace/image:tag
   ```

   In the example above, GitLab Runner looks at `registry.example.com:5000` for the
   image `namespace/image:tag`.

You can add configuration for as many registries as you want, adding more
registries to the `"auths"` hash as described above.

The full `hostname:port` combination is required everywhere
for the runner to match the `DOCKER_AUTH_CONFIG`. For example, if
`registry.example.com:5000/namespace/image:tag` is specified in the `.gitlab-ci.yml` file,
then the `DOCKER_AUTH_CONFIG` must also specify `registry.example.com:5000`.
Specifying only `registry.example.com` does not work.

### Configuring a runner

If you have many pipelines that access the same registry, you should
set up registry access at the runner level. This
allows pipeline authors to have access to a private registry just by
running a job on the appropriate runner. It also helps simplify registry
changes and credential rotations.

This means that any job on that runner can access the
registry with the same privilege, even across projects. If you need to
control access to the registry, you need to be sure to control
access to the runner.

To add `DOCKER_AUTH_CONFIG` to a runner:

1. Modify the runner's `config.toml` file as follows:

   ```toml
   [[runners]]
     environment = ["DOCKER_AUTH_CONFIG={\"auths\":{\"registry.example.com:5000\":{\"auth\":\"bXlfdXNlcm5hbWU6bXlfcGFzc3dvcmQ=\"}}}"]
   ```

   - The double quotes included in the `DOCKER_AUTH_CONFIG`
     data must be escaped with backslashes. This prevents them from being
     interpreted as TOML.
   - The `environment` option is a list. Your runner may
     have existing entries and you should add this to the list, not replace
     it.

1. Restart the runner service.

### Use a Credentials Store

To configure a Credentials Store:

1. To use a Credentials Store, you need an external helper program to interact with a specific keychain or external store.
   Make sure the helper program is available in the GitLab Runner `$PATH`.

1. Make GitLab Runner use it. There are two ways to accomplish this. Either:

   - Create a
     [CI/CD variable](../variables/index.md)
     `DOCKER_AUTH_CONFIG` with the content of the
     Docker configuration file as the value:

     ```json
       {
         "credsStore": "osxkeychain"
       }
     ```

   - Or, if you're running self-managed runners, add the above JSON to
     `${GITLAB_RUNNER_HOME}/.docker/config.json`. GitLab Runner reads this configuration file
     and uses the needed helper for this specific repository.

`credsStore` is used to access **all** the registries.
If you use both images from a private registry and public images from Docker Hub,
pulling from Docker Hub fails. Docker daemon tries to use the same credentials for **all** the registries.

### Use Credential Helpers

> Introduced in GitLab Runner 12.0.
As an example, let's assume that you want to use the `<aws_account_id>.dkr.ecr.<region>.amazonaws.com/private/image:latest`
image. This image is private and requires you to sign in to a private container registry.

To configure access for `<aws_account_id>.dkr.ecr.<region>.amazonaws.com`, follow these steps:

1. Make sure [`docker-credential-ecr-login`](https://github.com/awslabs/amazon-ecr-credential-helper) is available in the GitLab Runner `$PATH`.
1. Have any of the following [AWS credentials setup](https://github.com/awslabs/amazon-ecr-credential-helper#aws-credentials).
   Make sure that GitLab Runner can access the credentials.
1. Make GitLab Runner use it. There are two ways to accomplish this. Either:

   - Create a [CI/CD variable](../variables/index.md)
     `DOCKER_AUTH_CONFIG` with the content of the
     Docker configuration file as the value:

     ```json
     {
       "credHelpers": {
         "<aws_account_id>.dkr.ecr.<region>.amazonaws.com": "ecr-login"
       }
     }
     ```

     This configures Docker to use the Credential Helper for a specific registry.

     Instead, you can configure Docker to use the Credential Helper for all Amazon Elastic Container Registry (ECR) registries:

     ```json
     {
       "credsStore": "ecr-login"
     }
     ```

   - Or, if you're running self-managed runners,
     add the previous JSON to `${GITLAB_RUNNER_HOME}/.docker/config.json`.
     GitLab Runner reads this configuration file and uses the needed helper for this
     specific repository.

1. You can now use any private image from `<aws_account_id>.dkr.ecr.<region>.amazonaws.com` defined in
   `image` and/or `services` in your `.gitlab-ci.yml` file:

   ```yaml
   image: <aws_account_id>.dkr.ecr.<region>.amazonaws.com/private/image:latest
   ```

   In the example, GitLab Runner looks at `<aws_account_id>.dkr.ecr.<region>.amazonaws.com` for the
   image `private/image:latest`.

You can add configuration for as many registries as you want, adding more
registries to the `"credHelpers"` hash.

### Use checksum to keep your image secure

We recommend using the image checksum in your job definition in your `.gitlab-ci.yml` file to verify the integrity of the image. A failed image integrity verification will prevent you from using a modified container.

To use the image checksum you have to append the checksum at the end:

```yaml
image: ruby:2.6.8@sha256:d1dbaf9665fe8b2175198e49438092fdbcf4d8934200942b94425301b17853c7
```

To get the image checksum, on the image `TAG` tab, view the `DIGEST` column.
For example, view the [Ruby image](https://hub.docker.com/_/ruby?tab=tags).
The checksum is a random string, like `6155f0235e95`.

You can also get the checksum of any image on your system with the command `docker images --digests`:

```shell
❯ docker images --digests
REPOSITORY                                                        TAG       DIGEST                                                                    (...)
gitlab/gitlab-ee                                                  latest    sha256:723aa6edd8f122d50cae490b1743a616d54d4a910db892314d68470cc39dfb24   (...)
gitlab/gitlab-runner                                              latest    sha256:4a18a80f5be5df44cb7575f6b89d1fdda343297c6fd666c015c0e778b276e726   (...)
```


### Success scenario

```
concurrent = 3
check_interval = 0

[[runners]]
  name = "gitlabrunner01"
  url = "https://gitlab.com/ci"
  token = "BLABLA"
  executor = "docker"
  builds_dir = "/builds"
  cache_dir = "/cache"
  environment = ["DOCKER_HOST=tcp://docker:2375/", "DOCKER_TLS_CERTDIR: \"\""]
  [runners.docker]
    tls_verify = false
    image = "docker:20.10.16"
    privileged = true
    disable_cache = false
    volumes = ["/cache:/cache", "/builds:/builds"]
    shm_size = 0
  [runners.cache]
```
