
export IMAGE_URL := "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-10-10/2023-10-10-raspios-bookworm-arm64-lite.img.xz"
export RUGPI_IMAGE := "ghcr.io/silitics/rugpi-bakery:latest"

export PREFIX := "tedge_rugpi_"
export BASE_IMAGE := replace_regex(file_stem(IMAGE_URL), ".img$", "")
export BASE_TAR := "build" / BASE_IMAGE + ".base.tar"
export CUSTOM_TAR := "build" / BASE_IMAGE + ".tedge.tar"

export VARIANT := ""
export IMAGE_NAME := env_var_or_default("IMAGE_NAME", PREFIX + `date +'%Y%m%d%H%M'`)
export OUTPUT_IMAGE := "build" / IMAGE_NAME + replace("." + VARIANT + ".img", "..", ".")
export BUILD_INFO := file_stem(IMAGE_NAME)

set-image FILE="images/pi45.toml":
    rm -f ./rugpi-bakery.toml
    ln -s {{FILE}} ./rugpi-bakery.toml

# Generate a version name (that can be used in follow up commands)
generate_version:
    @echo "{{IMAGE_NAME}}"

# Show the install paths
show:
    @echo "IMAGE_URL: {{IMAGE_URL}}"
    @echo "IMAGE_NAME: {{IMAGE_NAME}}"
    @echo "BASE_TAR: {{BASE_TAR}}"
    @echo "CUSTOM_TAR: {{CUSTOM_TAR}}"
    @echo "OUTPUT_IMAGE: {{OUTPUT_IMAGE}}"
    @echo "BUILD_INFO: {{BUILD_INFO}}"

# Clean build
clean:
    @rm -Rf build/

# Download and extract the base image
extract:
    ./run-bakery extract "{{IMAGE_URL}}" "{{BASE_TAR}}"

# Apply recipes to the base image
customize:
    echo "{{BUILD_INFO}}" > "{{justfile_directory()}}/recipes/build-info/files/.build_info"
    ./run-bakery customize "{{BASE_TAR}}" "{{CUSTOM_TAR}}"

# Create the image that can be flashed to an SD card or applied using the rugpi interface
bake:
    ./run-bakery bake "{{CUSTOM_TAR}}" "{{OUTPUT_IMAGE}}"
    @echo ""
    @echo "Compressing image"
    xz -0 -v "{{OUTPUT_IMAGE}}"
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
build-all: extract customize bake

# Build the image from an already downloaded image
build-local: customize bake

# Publish latest image to Cumulocity
publish:
    cd {{justfile_directory()}} && ./scripts/upload-c8y.sh
