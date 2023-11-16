
export IMAGE_URL := "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz"
# Currently the bookworm image does not work for reasons unknown
#export IMAGE_URL := "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-10-10/2023-10-10-raspios-bookworm-arm64-lite.img.xz"

export IMAGE_NAME := replace_regex(file_stem(IMAGE_URL), ".img$", "")
export BASE_TAR := "build" / IMAGE_NAME + ".base.tar"
export CUSTOM_TAR := "build" / IMAGE_NAME + ".tedge.tar"
export OUTPUT_IMAGE := "build" / IMAGE_NAME + ".tedge.img"

# Show the install paths
show:
    @echo "IMAGE_URL: {{IMAGE_URL}}"
    @echo "IMAGE_NAME: {{IMAGE_NAME}}"
    @echo "BASE_TAR: {{BASE_TAR}}"
    @echo "CUSTOM_TAR: {{CUSTOM_TAR}}"
    @echo "OUTPUT_IMAGE: {{OUTPUT_IMAGE}}"

# Download and extract the base image
extract:
    ./run-bakery extract "{{IMAGE_URL}}" "{{BASE_TAR}}"

# Apply recipes to the base image
customize:
    ./run-bakery customize "{{BASE_TAR}}" "{{CUSTOM_TAR}}"

# Create the image that can be flashed to an SD card or applied using the rugpi interface
bake:
    ./run-bakery bake "{{CUSTOM_TAR}}" "{{OUTPUT_IMAGE}}"
    @echo ""
    @echo "Image created successfully. Check below for options on how to use the image"
    @echo ""
    @echo "Option 1: Use the Raspberry Pi Imager to flash the image to an SD card"
    @echo ""
    @echo "    {{OUTPUT_IMAGE}}"
    @echo ""
    @echo "Option 2: If the device is already running a rugpi image, open the http://tedge-rugpi:8088 website and install the following image:"
    @echo ""
    @echo "    {{OUTPUT_IMAGE}}"
    @echo ""

build-all: extract customize bake
build-local: customize bake
