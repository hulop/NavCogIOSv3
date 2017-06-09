# NavCog3

## Example of localization
This app uses BasicLocalizer in [blelocpp](http://github.com/hulop/blelocpp) library to localize user's location by observing bluetooth LE beacons signals.

You need to provide a [model file](https://github.com/hulop/NavCogIOSv3/wiki/Prepare-data-for-localization) for localization.

## UI Mode
- **Blind User Mode**: This mode is for blind users.
- **Wheel Chair / General Pedestrian Mode**: This mode is mainly for wheel chair users and also all sighted users.

## NavCog3 Tools
The workspace also includes the foolowing tools.

- **NavCogFingerPrint**: For fingerprintig
- **NavCogTool**: For simulate blind user navigation commands

## Pre-Requisites
- [Mantle](https://github.com/Mantle/Mantle) (MIT License)
- [Watson Developer Cloud Swift SDK](https://github.com/watson-developer-cloud/swift-sdk) (Apache 2.0)
- [blelocpp (BLE localization library)](https://github.com/hulop/blelocpp) (MIT License)

## Build

1. Install [CocoaPods](https://cocoapods.org/).
2. In the project directory, run `pod install`.
3. install [Carthage](https://github.com/Carthage/Carthage).
4. In the project directory, run `carthage bootstrap --platfom ios`.
5. Open NavCog3.xcworkspace
6. Build NavCog3 project with xcode.

## Setup

See [wiki](https://github.com/hulop/NavCogIOSv3/wiki) for set up servers and data.

----
## About
[About HULOP](https://github.com/hulop/00Readme)

## Icons
Icons in NavCogFingerPrint are from [https://github.com/IBM-Design/icons](https://github.com/IBM-Design/icons)

## License
[MIT](http://opensource.org/licenses/MIT)

## README
This Human Scale Localization Platform library is intended solely for use with an Apple iOS product and intended to be used in conjunction with officially licensed Apple development tools and further customized and distributed under the terms and conditions of your licensed Apple developer program.

