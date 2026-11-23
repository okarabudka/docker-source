# Image matrix: PHP versions x flavours x targets.
#   docker buildx bake                              # everything
#   PHP_VERSIONS=8.4,8.5 docker buildx bake          # selected versions
#   docker buildx bake 8_5-fpm-alpine-dev            # one image
# Tags: <version>-<flavour> (prod) and <version>-<flavour>-dev, e.g. 8.5-fpm, 8.5-apache-dev.

variable "REGISTRY" {
  default = "ghcr.io/okarabudka/php"
}

variable "PHP_VERSIONS" {
  type    = list(string)
  default = ["8.1", "8.2", "8.3", "8.4", "8.5"]
}

# Release version (e.g. v1.2.0 or 1.2.0); adds an immutable tag next to the rolling one.
variable "RELEASE" {
  default = ""
}

# Set to 1 in GitHub Actions to use the GitHub cache, one scope per image.
variable "GHA_CACHE" {
  default = ""
}

variable "FLAVOURS" {
  default = {
    "apache"     = { variant = "apache", os = "trixie" }
    "fpm"        = { variant = "fpm", os = "trixie" }
    "fpm-alpine" = { variant = "fpm", os = "alpine" }
  }
}

function "tag" {
  params = [version, flavour, stage]
  result = "${version}-${flavour}${stage == "dev" ? "-dev" : ""}"
}

group "default" {
  targets = ["php"]
}

target "_common" {
  context    = "."
  dockerfile = "php/Dockerfile"
  labels = {
    "org.opencontainers.image.source"   = "https://github.com/okarabudka/docker-source"
    "org.opencontainers.image.licenses" = "MIT"
  }
}

target "php" {
  name     = replace(tag(version, flavour, stage), ".", "_")
  inherits = ["_common"]
  matrix = {
    version = PHP_VERSIONS
    flavour = keys(FLAVOURS)
    stage   = ["dev", "prod"]
  }
  target = stage
  args = {
    PHP_VERSION = version
    VARIANT     = FLAVOURS[flavour].variant
    OS          = FLAVOURS[flavour].os
  }
  labels = {
    "org.opencontainers.image.title"       = "php:${tag(version, flavour, stage)}"
    "org.opencontainers.image.description" = "PHP ${version} ${flavour} ${stage} image"
  }
  cache-from = GHA_CACHE != "" ? ["type=gha,scope=${tag(version, flavour, stage)}"] : []
  cache-to   = GHA_CACHE != "" ? ["type=gha,scope=${tag(version, flavour, stage)},mode=max"] : []
  tags = compact([
    "${REGISTRY}:${tag(version, flavour, stage)}",
    RELEASE != "" ? "${REGISTRY}:${tag(version, flavour, stage)}-${trimprefix(RELEASE, "v")}" : "",
  ])
}
