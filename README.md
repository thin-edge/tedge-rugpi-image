# thin-edge.io image using rugpi

The repository can be used to build custom Raspberry Pi images with thin-edge.io and rugpi (for firmware updates) pre-installed.

**Compatible devices**

* Raspberry PI 2B Rev 1.2 (using u-boot)
* Raspberry PI Zero 2 W (using u-boot)
* Raspberry PI 3 (using u-boot)
* Raspberry Pi 4 (using tryboot)
* Raspberry Pi 5 (using tryboot)

## Building an image

To run the build tasks, install [just](https://just.systems/man/en/chapter_5.html).

1. Create the image (including downloading the supported base Raspberry Pi image) using:

    ```sh
    just VARIANT=pi45 build-all
    ```

    Possible variants are:

    * pi45
    * pi4
    * pi023

    ```sh
    just PROFILE=wifi VARIANT=pi4 build-all
    ```

2. Using the path to the image shown in the console to flash the image to the Raspberry Pi.


For further information, checkout the [Rugpi quick start guide](https://oss.silitics.com/rugpi/docs/getting-started).

## Building an image with WIFI credentials

For devices that only support WIFI (e.g. don't have an ethernet adapter), the WIFI credentials are required to be part of the image, otherwise you don't have any way to connect via SSH to your device.

In the future this process will be looked to be improved, and potentially the standard raspberry pi way of using the wpa_supplicant will enable to work out of the box (so that you don't have to bake credentials into the image, and only add them when writing to flash).

The default WIFI credentials are as follows, though it assumes that the given WIFI setup is a non-trusted network that is only used for bootstrapping, and then a secure WIFI network is configured.

|SSID|Password|
|----|--------|
|onboarding_jail|onboarding_jail|

1. Create the image (including downloading the supported base Raspberry Pi image) using:

    ```sh
    just PROFILE=wifi VARIANT=pi023 build-all
    ```

    Possible variants are:

    * pi023
    * pi4
    * pi45

    This profile will use pre-baked credentials for the WIFI which are defined in [profiles/wifi.toml](profiles/wifi.toml).
