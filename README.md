# docker-source

[![CI](https://github.com/okarabudka/docker-source/actions/workflows/ci.yml/badge.svg)](https://github.com/okarabudka/docker-source/actions/workflows/ci.yml)

PHP base images for development and production, built from one parameterised Dockerfile on top of the official
`php` images. Every PHP version from 8.1 to 8.5 comes as Apache, PHP-FPM and PHP-FPM on Alpine, each with a `dev`
and a `prod` target. The images run as a non-root user, ship the same extension set and are smoke-tested in CI
before they are published to GitHub Container Registry. The repository also holds a small multi-stage template for Go
services.

## Why it exists

Most PHP projects need the same runtime: a handful of PECL extensions, Composer, Xdebug that does not slow down every
request, a mail catcher, and a production image without any of that. Each project used to define its own Dockerfile,
and they drifted apart. These images make those decisions once:

- one Dockerfile and one bake file instead of a file per version and flavour;
- dev and prod built from the same base, so they differ only in the tools on top;
- no `sudo`, no root processes, no unpinned downloads in the build.

## Images

`ghcr.io/okarabudka/php:<tag>`

| PHP | Apache (Debian trixie)        | PHP-FPM (Debian trixie)  | PHP-FPM (Alpine)                       |
|-----|-------------------------------|--------------------------|----------------------------------------|
| 8.5 | `8.5-apache`, `8.5-apache-dev` | `8.5-fpm`, `8.5-fpm-dev` | `8.5-fpm-alpine`, `8.5-fpm-alpine-dev` |
| 8.4 | `8.4-apache`, `8.4-apache-dev` | `8.4-fpm`, `8.4-fpm-dev` | `8.4-fpm-alpine`, `8.4-fpm-alpine-dev` |
| 8.3 | `8.3-apache`, `8.3-apache-dev` | `8.3-fpm`, `8.3-fpm-dev` | `8.3-fpm-alpine`, `8.3-fpm-alpine-dev` |
| 8.2 | `8.2-apache`, `8.2-apache-dev` | `8.2-fpm`, `8.2-fpm-dev` | `8.2-fpm-alpine`, `8.2-fpm-alpine-dev` |
| 8.1 | `8.1-apache`, `8.1-apache-dev` | `8.1-fpm`, `8.1-fpm-dev` | `8.1-fpm-alpine`, `8.1-fpm-alpine-dev` |

Tags without a suffix are the `prod` target. Releases add an immutable tag next to the rolling one, e.g.
`8.5-fpm-1.2.0`. Images are built for `linux/amd64` and `linux/arm64`.

PHP 8.1 no longer gets security fixes upstream; it stays in the matrix for legacy projects only.

### Extensions

All images: `amqp`, `apcu`, `bcmath`, `exif`, `gd`, `imagick`, `intl`, `mysqli`, `opcache`, `pcntl`, `pdo_mysql`,
`pdo_pgsql`, `redis`, `soap`, `sockets`, `xsl`, `zip`, plus everything the official image compiles in (`curl`,
`mbstring`, `pdo_sqlite`, `sodium`, ...). `dev` adds `xdebug`.

The list is a build argument, so a custom set is one flag away:

```bash
docker buildx build -f php/Dockerfile --target prod \
  --build-arg PHP_VERSION=8.5 --build-arg VARIANT=fpm \
  --build-arg PHP_EXTENSIONS="intl opcache pdo_pgsql redis" -t my/php:8.5-fpm .
```

### dev and prod

|                         | `dev`                                         | `prod`                                       |
|-------------------------|-----------------------------------------------|----------------------------------------------|
| `php.ini`               | `php.ini-development`                         | `php.ini-production`                         |
| OPcache                 | revalidates files on every request            | no timestamp checks, 256 MB, tuned buffers   |
| Xdebug                  | installed, off until `XDEBUG_MODE` is set     | not installed                                |
| Composer, git, unzip    | yes                                           | no                                           |
| Mail                    | `mail()` goes through msmtp to `mailpit:1025` | no sendmail                                  |
| User                    | `app` (UID/GID 1000)                          | `app` (UID/GID 1000)                         |
| Health check            | yes                                           | yes                                          |

Both targets:

- run as the unprivileged user `app`; there is no `sudo` in any image;
- Apache listens on port **8080**, PHP-FPM on **9000**;
- the document root is `/var/www/html/public` (`APACHE_DOCUMENT_ROOT` changes it), the working directory is
  `/var/www/html`;
- have a `HEALTHCHECK`: Apache answers `mod_status` on localhost, PHP-FPM answers its ping page over FastCGI;
- keep `install-php-extensions` (pinned release), so images built `FROM` them can add extensions.

### Configuration

| Variable                      | Default (dev / prod) | Effect                                                   |
|-------------------------------|----------------------|----------------------------------------------------------|
| `PHP_MEMORY_LIMIT`            | `256M`               | `memory_limit`                                           |
| `PHP_UPLOAD_MAX_FILESIZE`     | `32M`                | `upload_max_filesize` and `post_max_size`                |
| `OPCACHE_VALIDATE_TIMESTAMPS` | `1` / `0`            | `opcache.validate_timestamps`                            |
| `XDEBUG_MODE`                 | `off` (dev)          | Xdebug mode, e.g. `debug`, `coverage`, `debug,develop`   |
| `MAIL_HOST`, `MAIL_PORT`      | `mailpit`, `1025`    | SMTP server for `mail()` (dev)                           |
| `PUID`, `PGID`                | unset                | Remap `app` to the host user; needs `--user root`        |
| `APACHE_DOCUMENT_ROOT`        | `/var/www/html/public` | Apache only                                            |

Xdebug connects to `host.docker.internal`. On Linux add `--add-host=host.docker.internal:host-gateway` (or
`extra_hosts` in compose).

#### Matching the host user

Files written to a bind mount belong to UID 1000. If your user has a different UID, either build with
`--build-arg UID=$(id -u) --build-arg GID=$(id -g)`, or start the container as root and let the entrypoint remap `app`
and drop privileges before PHP starts:

```bash
docker run --rm --user root -e PUID="$(id -u)" -e PGID="$(id -g)" -v "$PWD":/var/www/html \
  ghcr.io/okarabudka/php:8.5-fpm-dev composer install
```

The process still runs as `app`, never as root.

## Usage

### docker run

```bash
# Apache with your project mounted, http://localhost:8080
docker run --rm -p 8080:8080 -v "$PWD":/var/www/html ghcr.io/okarabudka/php:8.5-apache-dev

# one-off commands
docker run --rm -v "$PWD":/var/www/html ghcr.io/okarabudka/php:8.5-fpm-dev composer install
docker run --rm -e XDEBUG_MODE=coverage -v "$PWD":/var/www/html ghcr.io/okarabudka/php:8.5-fpm-dev \
  vendor/bin/phpunit --coverage-text
```

### docker compose

[`examples/compose.yaml`](examples/compose.yaml) runs Nginx, PHP-FPM (`8.5-fpm-dev`), MariaDB and Mailpit with a
one-page app that checks the database connection and sends a test mail:

```bash
docker compose -f examples/compose.yaml up
```

Open http://localhost:8080 for the app and http://localhost:8025 for Mailpit. If the image is not published or pulled
yet, compose builds it from this repository.

### FROM in your own Dockerfile

```dockerfile
FROM ghcr.io/okarabudka/php:8.5-fpm-dev AS dev

FROM ghcr.io/okarabudka/php:8.5-fpm-dev AS vendor
COPY --chown=app:app composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --prefer-dist --no-progress

FROM ghcr.io/okarabudka/php:8.5-fpm AS prod
USER root
RUN install-php-extensions mongodb
USER app
COPY --chown=app:app --from=vendor /var/www/html/vendor ./vendor
COPY --chown=app:app . .
```

## Build and test locally

Requirements: Docker with Buildx and make. Nothing else is installed on the host; linters run in containers.

```bash
make build                    # whole matrix (5 versions x 3 flavours x dev/prod = 30 images)
make build VERSIONS="8.5"     # one version, 6 images
make test VERSIONS="8.5"      # smoke tests against the built images
make lint                     # hadolint for Dockerfiles, shellcheck for scripts
make sizes                    # list built images and their size
```

The bake file can also be used directly:

```bash
docker buildx bake --print                       # show the resolved matrix
PHP_VERSIONS=8.4,8.5 docker buildx bake --load   # selected versions
docker buildx bake --load 8_5-fpm-alpine-dev     # one image (dots become underscores)
```

`tests/smoke.sh` checks every image for:

- the expected PHP version and extension list;
- UID 1000 for commands and for the server process, no `sudo`;
- a container that becomes healthy and serves a test page (Apache over HTTP, PHP-FPM over FastCGI with `cgi-fcgi`);
- dev: Xdebug loaded but off, `XDEBUG_MODE` switches it on, Composer, git, msmtp, PUID/PGID remap;
- prod: no Xdebug, Composer or git, OPcache without timestamp checks, `display_errors` off.

### Image sizes

Measured from local `linux/amd64` builds (n/a: not built locally, covered by CI):

| PHP | `apache` | `apache-dev` | `fpm` | `fpm-dev` | `fpm-alpine` | `fpm-alpine-dev` |
|-----|----------|--------------|-------|-----------|--------------|------------------|
| 8.5 | 714MB | 764MB | 709MB | 761MB | 325MB | 345MB |
| 8.4 | 699MB | 750MB | 690MB | 742MB | 307MB | 327MB |
| 8.3 | 693MB | 744MB | n/a | n/a | n/a | n/a |

For comparison, the official base images are about 520 MB (`php:8.5-apache`) and 115 MB (`php:8.5-fpm-alpine`).
Most of the difference comes from the runtime libraries of the extensions, ImageMagick for `imagick` above all; a
smaller `PHP_EXTENSIONS` list gives a smaller image.

## CI and releases

- **Lint**: hadolint, shellcheck, gitleaks over the full history, bake definition check.
- **Build and test**: one job per PHP version builds its six images for `linux/amd64` with the GitHub Actions cache
  and runs the smoke tests. On `main`, PHP 8.5 is also built and tested on a native arm64 runner.
- **Go**: builds the Go example and checks its health endpoint.
- **Release**: a tag `v*` builds and tests the matrix again, then pushes multi-arch images (`amd64`, `arm64` via
  QEMU) to `ghcr.io/okarabudka/php` with `GITHUB_TOKEN`.
- **Dependabot** keeps base images, the compose example and GitHub Actions up to date.

## Go service template

[`go/Dockerfile`](go/Dockerfile) builds a static Go binary with BuildKit cache mounts for modules and the build
cache, and runs it on `gcr.io/distroless/static-debian13:nonroot`. The distroless image has no shell, so the health
check calls the binary itself. [`go/example/`](go/example) is a minimal HTTP service that the template is tested with:

```bash
docker build -f go/Dockerfile -t go-example go/example
docker run --rm -p 8080:8080 go-example
make test-go
```

## Repository layout

```
php/Dockerfile          base, server-apache, server-fpm, dev and prod stages
php/conf/               php.ini overrides, Apache vhost and ports, PHP-FPM pool
php/bin/                entrypoint (PUID/PGID remap) and PHP-FPM health check
docker-bake.hcl         version x flavour x target matrix and tags
Makefile                build, test, lint, sizes
tests/                  smoke tests and the test page
examples/               Nginx + PHP-FPM + MariaDB + Mailpit
go/                     Go multi-stage template and example service
.github/                CI, release workflow and Dependabot
```

## Status

Maintained.

## License

MIT, see [LICENSE](LICENSE).
