# NavCog3

## Example of localization
This app uses BasicLocalizer in [blelocpp](https://github.com/hulop/blelocpp) library to localize user's location by observing bluetooth LE beacons signals.

You need to provide a [model file](https://github.com/hulop/NavCogIOSv3/wiki/Prepare-data-for-localization) for localization.

## UI Mode
- **Blind User Mode**: This mode is for blind users.
- **Wheel Chair / General Pedestrian Mode**: This mode is mainly for wheel chair users and also all sighted users.

## NavCog3 Tools
The project also includes the following tools.

- **NavCogFP**: For fingerprinting
- **NavCogTool**: For simulate blind user navigation commands
- **NavCogPreview**: For virtual preview

## Dependencies
- [FormatterKit](https://github.com/mattt/FormatterKit) (MIT License)
- [HLPDialog](https://github.com/hulop/HLPDialog) (MIT License)
- [HLPLocationManager](https://github.com/hulop/HLPLocationManager) (MIT License)
- [HLPWebView](https://github.com/hulop/HLPWebView) (MIT License)
- [Mantle](https://github.com/Mantle/Mantle) (MIT License)
- [ZipArchive](https://github.com/ZipArchive/ZipArchive) (MIT License)

## Build
1. install [Carthage](https://github.com/Carthage/Carthage).
2. In the project directory, run `carthage bootstrap --platform iOS`.
3. install [Cocoapods](https://cocoapods.org/)
4. In the project directory, run `pod install`
5. Open NavCog3.xcworkspace
6. Build NavCog3 target with Xcode.

\# if you archive the app for AppStore, `Frameworks` directory in `Carthage/Build/iOS/HLPDialog.framework` should be removed.

## Setup
See [wiki](https://github.com/hulop/NavCogIOSv3/wiki) for set up servers and data.

----
## About
[About HULOP](https://github.com/hulop/00Readme)

## Icons
Icons in NavCogFP are from [https://github.com/IBM-Design/icons](https://github.com/IBM-Design/icons)

## License
[MIT](https://opensource.org/licenses/MIT)

## README
This Human Scale Localization Platform library is intended solely for use with an Apple iOS product and intended to be used in conjunction with officially licensed Apple development tools and further customized and distributed under the terms and conditions of your licensed Apple developer program.

	