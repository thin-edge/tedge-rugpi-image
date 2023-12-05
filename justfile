
export IMAGE_URL_ARM64 := "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-10-10/2023-10-10-raspios-bookworm-arm64-lite.img.xz"
export IMAGE_URL_ARMHF := "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-10-10/2023-10-10-raspios-bookworm-armhf-lite.img.xz"

export IMAGE_ARCH := "arm64"

export IMAGE_URL := if IMAGE_ARCH != "armhf" { IMAGE_URL_ARM64 } else { IMAGE_URL_ARMHF }
export RUGPI_IMAGE := "ghcr.io/silitics/rugpi-bakery:latest"

export PREFIX := "tedge_rugpi_"
export PROFILE := "default"

export BASE_IMAGE := replace_regex(file_stem(IMAGE_URL), ".img$", "")
export BASE_TAR := "build" / BASE_IMAGE + ".base.tar"
export CUSTOM_TAR := "build" / BASE_IMAGE + "." + PROFILE + ".tar"

export CUSTOMIZATION_PROFILE := "profiles" / PROFILE + ".toml"
export VARIANT := "pi45"
export IMAGE_CONFIG := "images/" + VARIANT + ".toml"
export VERSION := env_var_or_default("VERSION", `date +'%Y%m%d.%H%M'`)
export IMAGE_NAME := PREFIX + PROFILE + "_" + VARIANT + "_" + VERSION
export OUTPUT_IMAGE := "build" / IMAGE_NAME + ".img"
export BUILD_INFO := IMAGE_NAME

# Generate a version name (that can be used in follow up commands)
generate_version:
    @echo "{{VERSION}}"

# Show the install paths
show:
    @echo "IMAGE_URL: {{IMAGE_URL}}"
    @echo "IMAGE_NAME: {{IMAGE_NAME}}"
    @echo "CUSTOMIZATION_PROFILE: {{CUSTOMIZATION_PROFILE}}"
    @echo "IMAGE_CONFIG: {{IMAGE_CONFIG}}"

    @echo "BASE_TAR: {{BASE_TAR}}"
    @echo "CUSTOM_TAR: {{CUSTOM_TAR}}"

    @echo "OUTPUT_IMAGE: {{OUTPUT_IMAGE}}"
    @echo "VERSION: {{VERSION}}"
    @echo "BUILD_INFO: {{BUILD_INFO}}"

# Setup binfmt tools
setup:
    docker run --privileged --rm tonistiigi/binfmt --install arm64,armhf

# Clean build
clean:
    @rm -Rf build/

# Download and extract the base image
extract:
    ./run-bakery extract "{{IMAGE_URL}}" "{{BASE_TAR}}"

# Apply recipes to the base image
customize:
    echo "{{BUILD_INFO}}" > "{{justfile_directory()}}/recipes/build-info/files/.build_info"
    ./run-bakery --config "{{CUSTOMIZATION_PROFILE}}" customize "{{BASE_TAR}}" "{{CUSTOM_TAR}}"

# Create the image that can be flashed to an SD card or applied using the rugpi interface
bake:
    ./run-bakery --config "{{IMAGE_CONFIG}}" bake "{{CUSTOM_TAR}}" "{{OUTPUT_IMAGE}}"
    @echo ""
    @echo "Compressing image"
    scripts/compress.sh "{{OUTPUT_IMAGE}}"
    @echo ""
    @echo ""
    @echo "Image created successfully. Check below for options on how to use the image"
    @echo ""
    @echo "Option 1: Use the Raspberry Pi Imager to flash the image to an SD card"
    @echo ""
    @echo "    {{justfile_directory()}}/{{OUTPUT_IMAGE}}.xz"
    @echo ""
    @echo "Option 2: If the device is already running a rugpi image, open the http://tedge-rugpi:8088 website and install the following image:"
    @echo ""
    @echo "    {{justfile_directory()}}/{{OUTPUT_IMAGE}}.xz"
    @echo ""

# Build the entire image
build-all: setup extract customize bake

# Build the image from an already downloaded image
build-local: customize bake

# Publish latest image to Cumulocity
publish:
    cd {{justfile_directory()}} && ./scripts/upload-c8y.sh

# Publish a given github release to Cumulocity (using external urls)
publish-external tag *args="":
    cd {{justfile_directory()}} && ./scripts/c8y-publish-release.sh {{tag}} {{args}}

build-all-variants: extract customize
    just VARIANT=pi023 bake
    # just VARIANT=pi4 bake
    just VARIANT=pi45 bake
