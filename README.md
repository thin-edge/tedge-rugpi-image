# Rugpi: Quick Start Template

## Building the image

1. Build the image

    ```sh
    ./run-bakery extract https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz build/base.tar
    ./run-bakery customize build/base.tar build/customized.tar
    ./run-bakery bake build/customized.tar build/customized.img
    ```

    **Notes**

    * The latest Raspberry Pi image does not work for reasons unknown
        ```
        https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-10-10/2023-10-10-raspios-bookworm-arm64-lite.img.xz
        ```

2. Flash the `build/image.img` image to the Raspberry Pi

For further information, checkout the [Rugpi quick start guide](https://oss.silitics.com/rugpi/docs/getting-started).

* [ ] Sensible configuration file defaults
    * configuration
    * log
* [ ] Set hostname based on hardware
