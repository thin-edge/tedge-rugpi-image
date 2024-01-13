set dotenv-load

export RUGPI_IMAGE := "ghcr.io/silitics/rugpi-bakery:feat-layers"

export PREFIX := "tedge_rugpi_"
export IMAGE := "tryboot"
export VERSION := env_var_or_default("VERSION", `date +'%Y%m%d.%H%M'`)
export IMAGE_NAME := PREFIX + IMAGE + "_" + VERSION
export OUTPUT_IMAGE := "build" / IMAGE_NAME + ".img"

# Generate a version name (that can be used in follow up commands)
generate_version:
    @echo "{{VERSION}}"

# Show the install paths
show:
    @echo "PREFIX={{PREFIX}}"
    @echo "IMAGE={{IMAGE}}"
    @echo "IMAGE_NAME={{IMAGE_NAME}}"
    @echo "VERSION={{VERSION}}"
    @echo "OUTPUT_IMAGE={{OUTPUT_IMAGE}}"

# Setup binfmt tools
# Note: technically only arm64,armhf are required, however install 'all' avoids the error message
# on arm64 hosts
setup:
    docker run --privileged --rm tonistiigi/binfmt --install all

# Clean rugpi cache and build folders
clean:
    @rm -Rf .rugpi
    @rm -Rf build/

# Create the image that can be flashed to an SD card or applied using the rugpi interface
build:
    mkdir -p "{{parent_directory(OUTPUT_IMAGE)}}"
    echo "{{IMAGE_NAME}}" > {{justfile_directory()}}/.image
    ./run-bakery bake image {{IMAGE}} {{OUTPUT_IMAGE}}
    just VERSION={{VERSION}} IMAGE={{IMAGE}} compress

# Compress
compress:
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


# Publish latest image to Cumulocity
publish:
    cd {{justfile_directory()}} && ./scripts/upload-c8y.sh

# Publish a given github release to Cumulocity (using external urls)
publish-external tag *args="":
    cd {{justfile_directory()}} && ./scripts/c8y-publish-release.sh {{tag}} {{args}}

# Trigger a release (by creating a tag)
release:
    git tag -a "{{VERSION}}" -m "{{VERSION}}"
    git push origin "{{VERSION}}"
    @echo
    @echo "Created release (tag): {{VERSION}}"
    @echo

#
# Help users to select the correct image for them
#
build-pi1:
    just IMAGE=u-boot-armhf build
    @echo
    @echo "This image can be applied to"
    @echo "  * pi1"
    @echo "  * pi2 (early models)"
    @echo "  * pizero"
    @echo

build-pizero:
    just IMAGE=u-boot-armhf build
    @echo
    @echo "This image can be applied to"
    @echo "  * pi1"
    @echo "  * pi2 (early models)"
    @echo "  * pizero"
    @echo

build-pi2:
    just IMAGE=u-boot build
    @echo
    @echo "This image can be applied to"
    @echo "  * pi2"
    @echo "  * pi3"
    @echo "  * pizero2"
    @echo

build-pi3:
    just IMAGE=u-boot build
    @echo
    @echo "This image can be applied to"
    @echo "  * pi2"
    @echo "  * pi3"
    @echo "  * pizero2"
    @echo

build-pizero2w:
    just IMAGE=u-boot build
    @echo
    @echo "This image can be applied to"
    @echo "  * pi2"
    @echo "  * pi3"
    @echo

build-pi4:
    just IMAGE=tryboot build
    @echo
    @echo "This image can be applied to"
    @echo "  * pi4"
    @echo "  * pi5"
    @echo

build-pi4-include-firmware:
    just IMAGE=pi4 build
    @echo
    @echo "This image can be applied to"
    @echo "  * pi4"
    @echo

build-pi5:
    just IMAGE=tryboot build
    @echo
    @echo "This image can be applied to"
    @echo "  * pi4"
    @echo "  * pi5"
    @echo
