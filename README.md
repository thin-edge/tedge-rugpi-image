# thin-edge.io image using rugpi

The repository can be used to build custom Raspberry Pi images with thin-edge.io and Rugpi for robust OTA Operation System updates.

## Compatible devices

**Using u-boot**

* Raspberry PI 1B
* Raspberry PI 2B Rev 1.2
* Raspberry PI Zero
* Raspberry PI Zero 2 W
* Raspberry PI 3

**Using tryboot**

* Raspberry Pi 4
* Raspberry Pi 5


## Images

The following images are included in this repository.

A profile determines what software and configuration is included in the image.

A variant is more hardware specific which uses the same profile but makes hardware specific tweaks based on the hardware limitations. For example Raspberry 2, 3 and Zero 2 W do not support the tryboot feature, so instead the u-boot bootloader is used to facilitate the robust OTA image updates.

The following sections describe the profiles and variants available.

### Profiles

|Profile|Description|
|-------|-----------|
|default|Default image which does not include WiFi credentials|
|wifi|All the contents of the default image but also has WiFi credentials included in the image. Suitable for devices without an ethernet adapter|


### Variants

|Variant|Supported Raspberry Pi Versions|Description|
|-------|-------------------------------|-----------|
|pi45|4 and 5|Does not include firmware so rpi4 needs to have up to date firmware for this image to work!|
|pi4|4|Includes firmware which enables the tryboot mechanism|
|pi023|2, 3 and Zero 2 W|Uses u-boot|


## Building

### Building an image without WIFI credentials (devices must have an ethernet adapter!)

To run the build tasks, install [just](https://just.systems/man/en/chapter_5.html).

1. Create the image (including downloading the supported base Raspberry Pi image) using:

    ```sh
    just VARIANT=pi45 build-all
    ```

2. Using the path to the image shown in the console to flash the image to the Raspberry Pi.

3. Subsequent A/B updates can be done using Cumulocity IoT or the local Rugpi interface on (localhost:8088)

For further information on Rugpi, checkout the [quick start guide](https://oss.silitics.com/rugpi/docs/getting-started).

### Building an image with WIFI credentials

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

### Building for Raspberry 1 or Zero

```sh
just IMAGE_ARCH=armhf PROFILE=armhf VARIANT=pi01 build-all
```

## Project Tasks

### Publishing a new release

1. Ensure you have everything that you want to include in your image

2. Trigger a release by using the following task:

    ```
    just release
    ```

    Take note of the git tag which is created as you will need this later if you want to add the firmware to the Cumulocity IoT firmware repository

3. Wait for the Github action to complete

4. Edit the newly created release in the Github Releases section of the repository

5. Publish the release

**Optional: Public images to Cumulocity IoT**


You will need [go-c8y-cli](https://goc8ycli.netlify.app/) and [gh](https://cli.github.com/) tools for this!

1. In the console, using go-c8y-cli, set your session to the tenant where you want to upload the firmware to

    ```
    set-session mytenant
    ```

2. Assuming you are still in the project's root directory

    Using the release tag created in the previous step, run the following:

    ```sh
    just publish-external <TAG>
    ```

    Example

    ```sh
    just publish-external 20231206.0800
    ```

    This script will create firmware items (name and version) in Cumulocity IoT. The firmware versions will be just links to the external artifacts which are available from the Github Release artifacts.

3. Now you can select the firmware in Cumulocity IoT to deploy to your devices (assuming you have flashed the base image to the device first ;)!
