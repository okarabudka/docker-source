#!/usr/bin/env bash
# Smoke tests for built images.
#   tests/smoke.sh ghcr.io/okarabudka/php:8.5-fpm ghcr.io/okarabudka/php:8.5-apache-dev ...
# Version, flavour and target are read from the tag: <version>-<apache|fpm|fpm-alpine>[-dev].
set -euo pipefail

EXTENSIONS=(amqp apcu bcmath exif gd imagick intl mysqli pcntl pdo_mysql pdo_pgsql redis soap sockets xsl zip "Zend OPcache")
FIXTURES="$(cd "$(dirname "$0")" && pwd)/fixtures/public"
HEALTH_TIMEOUT=60

failures=0
containers=()

cleanup() {
    if [ "${#containers[@]}" -gt 0 ]; then
        docker rm -f "${containers[@]}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }

# expect <description> <expected> <actual>
expect() {
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected '$2', got '$3')"; fi
}

# expect_ok <description> <command...>
expect_ok() {
    local description=$1
    shift
    if "$@" >/dev/null 2>&1; then pass "${description}"; else fail "${description}"; fi
}

# expect_fail <description> <command...>
expect_fail() {
    local description=$1
    shift
    if "$@" >/dev/null 2>&1; then fail "${description}"; else pass "${description}"; fi
}

run() { docker run --rm "${image}" "$@"; }
php_eval() { run php -r "$1"; }

wait_healthy() {
    local container=$1 status
    for _ in $(seq "${HEALTH_TIMEOUT}"); do
        status=$(docker inspect -f '{{.State.Health.Status}}' "${container}")
        case "${status}" in
            healthy) return 0 ;;
            unhealthy) break ;;
        esac
        sleep 1
    done
    docker logs "${container}" >&2 || true
    return 1
}

test_image() {
    image=$1
    local tag=${image##*:} version flavour target
    version=${tag%%-*}
    flavour=${tag#*-}
    target=prod
    if [ "${flavour%-dev}" != "${flavour}" ]; then
        target=dev
        flavour=${flavour%-dev}
    fi
    echo "${image} (PHP ${version}, ${flavour}, ${target})"

    expect "PHP version" "${version}" "$(php_eval 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')"

    local modules ext
    modules=$(run php -m)
    for ext in "${EXTENSIONS[@]}"; do
        expect_ok "extension ${ext}" grep -qixF "${ext}" <<<"${modules}"
    done

    expect "runs as uid 1000" "1000" "$(run id -u)"
    expect_fail "no sudo" run sh -c 'command -v sudo'

    local name="smoke-${tag}-$$"
    docker run -d --name "${name}" -v "${FIXTURES}:/var/www/html/public:ro" "${image}" >/dev/null
    containers+=("${name}")
    expect_ok "container becomes healthy" wait_healthy "${name}"
    expect "server process is not root" "1000" \
        "$(docker exec "${name}" awk '/^Uid:/ { print $2 }' /proc/1/status)"

    local body
    if [ "${flavour}" = "apache" ]; then
        body=$(docker exec "${name}" curl -fsS http://127.0.0.1:8080/ || true)
    else
        body=$(docker exec -e SCRIPT_FILENAME=/var/www/html/public/index.php -e REQUEST_METHOD=GET "${name}" \
            cgi-fcgi -bind -connect 127.0.0.1:9000 || true)
    fi
    expect_ok "server answers with the test page" grep -qF "smoke-ok ${version}" <<<"${body}"

    if [ "${target}" = "dev" ]; then
        expect_ok "xdebug is loaded" grep -qixF xdebug <<<"${modules}"
        expect "xdebug is off by default" "" "$(php_eval 'echo implode(",", xdebug_info("mode"));')"
        expect "XDEBUG_MODE enables xdebug" "debug" \
            "$(docker run --rm -e XDEBUG_MODE=debug "${image}" php -r 'echo implode(",", xdebug_info("mode"));')"
        expect_ok "composer" run composer --version
        expect_ok "git" run git --version
        # --pretend validates the sendmail_path command line without connecting (expanded in the container)
        # shellcheck disable=SC2016
        expect_ok "sendmail_path is a valid msmtp call" run sh -c \
            'printf "Subject: smoke\n\nok\n" | $(php -r "echo ini_get(\"sendmail_path\");") --pretend dev@example.com'
        expect "PUID/PGID remap" "4321:4321" \
            "$(docker run --rm --user root -e PUID=4321 -e PGID=4321 "${image}" sh -c 'echo "$(id -u):$(id -g)"')"
    else
        expect_fail "no xdebug" grep -qixF xdebug <<<"${modules}"
        expect_fail "no composer" run sh -c 'command -v composer'
        expect_fail "no git" run sh -c 'command -v git'
        expect "opcache does not revalidate" "0" "$(php_eval 'echo ini_get("opcache.validate_timestamps");')"
        expect "display_errors off" "" "$(php_eval 'echo ini_get("display_errors");')"
    fi

    docker rm -f "${name}" >/dev/null
}

if [ "$#" -eq 0 ]; then
    echo "usage: $0 <image> [<image>...]" >&2
    exit 2
fi

for image_arg in "$@"; do
    test_image "${image_arg}"
done

if [ "${failures}" -gt 0 ]; then
    echo "${failures} check(s) failed"
    exit 1
fi
echo "all checks passed"
