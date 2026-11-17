# Docker Source

Dockerfiles, configs and entrypoint scripts for PHP development images (Apache and PHP-FPM, PHP 7.4 to 8.3) and a Go
service build template.

## Context

Built between February 2023 and July 2024 as a personal collection of base images for local PHP development, so
projects can share the same PHP runtime, extensions and developer tooling instead of each defining its own. New PHP
versions were added over time, and a Go multi-stage build template was added in May 2024.

## Features

- **php-apache** images (`php-apache/7.4`, `8.1`, `8.2`, `8.3`), based on the official `php:<version>-apache` images:
  - PHP extensions via `install-php-extensions`, e.g. amqp, gd, intl, pdo_mysql, redis, memcached, imagick, xdebug,
    opcache, soap
  - Image tools (ImageMagick, jpegoptim, optipng, webp, Inkscape, Ghostscript) and wkhtmltopdf
  - `mhsendmail` for sending mail to MailHog
  - Self-signed SSL certificate, Apache modules rewrite, ssl, headers, expires, proxy, vhost_alias; document root
    `/var/www/public`
- **php-fpm** images (`php-fpm/8.1`, `8.2`, `8.3`), based on Debian bullseye with PHP packages from the Sury
  repository, including pgsql, mysql, redis, memcached, imagick, vips, yaml and xdebug; FPM listens on
  port 9000 and logs to stderr
- Non-root `developer` user with passwordless sudo; in the Apache images UID/GID can be adjusted at start-up via
  `PUID` / `PGID`
- Entrypoint helpers: add `host.docker.internal` to `/etc/hosts`, copy SSH keys from root to the developer user
- **go**: multi-stage Dockerfile (Go 1.22 alpine builder, alpine runner) for a service in an `app/` directory

## Tech stack

- Docker
- PHP 7.4 / 8.1 / 8.2 / 8.3, Apache, PHP-FPM, Composer
- Debian bullseye, Bash
- Go 1.22 (template)

## Architecture

- `php-apache/<version>.Dockerfile`, `php-fpm/<version>.Dockerfile`: one Dockerfile per PHP version; the build context
  is the repository root
- `configs/`: shared `php.ini` files (`php7.4.ini`, `php8.ini`), Apache vhost, OpenSSL config, FPM pool configs
- `scripts/`: `entrypoint.sh` (Apache), `entrypoint-php-fpm.sh`, `set-puid.sh`, `add-host-alias.sh`,
  `copy-ssh-keys.sh`, copied into `/usr/local/bin`
- `go/Dockerfile`: standalone template, expects the Go sources in `app/` (entry point `cmd/app/main.go`) and a
  config file in the build context

Note: `php-apache/8.2.Dockerfile` currently uses the `php:8.3-apache` base image. The images are intended for local
development only (passwordless sudo, Xdebug, disabled SSH host key checking).

## Getting started

Build from the repository root:

```bash
docker build -t php-apache:8.3 -f php-apache/8.3.Dockerfile .
docker build -t php-fpm:8.3 -f php-fpm/8.3.Dockerfile .
```

Push to your own registry:

```bash
docker tag php-fpm:8.3 <registry-user>/php-fpm:8.3
docker push <registry-user>/php-fpm:8.3
```

Run with a matching host user ID:

```bash
docker run -d -p 8080:80 -e PUID="$(id -u)" -e PGID="$(id -g)" -v "$PWD":/var/www php-apache:8.3
```

Go template (inside a project that provides `app/`):

```bash
docker build -t prod-service:local .
docker run prod-service:local
```

## Testing

There are no automated tests.

## Status

Not actively developed; last update in July 2024.

## License

MIT, see [LICENSE](LICENSE).
