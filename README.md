# NavCog3

# Example of localization
This app uses BasicLocalizer in [blelocpp](http://github.com/hulop/blelocpp) library to localize user's location by observing bluetooth LE beacons signals.

You need to provide [2d map data](https://github.com/hulop/00Readme/blob/master/quick_start/beacon_2d.md) for localization.

# UI Mode
## Blind User Mode
This mode is for blind users.
## Wheel Chair Mode
This mode is mainly for wheel chair users and also all sighted users.

## Pre-Requisites
- [Mantle 2.0.7](https://github.com/Mantle/Mantle) (MIT License)
- [Alamofire 3.5.1](https://github.com/Alamofire/Alamofire) (MIT License)
- [Watson Developer Cloud Swift SDK 0.8.2](https://github.com/watson-developer-cloud/swift-sdk) (Apache 2.0)
- [blelocpp (BLE localization library)](https://github.com/hulop/blelocpp) (MIT License)
- [Freddy N/A](https://github.com/bignerdranch/Freddy)	(MIT License) (pre-req for Watson Swift SDK)

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


## License
[MIT](http://opensource.org/licenses/MIT)

## README
This Human Scale Localization Platform library is intended solely for use with an Apple iOS product and intended to be used in conjunction with officially licensed Apple development tools and further customized and distributed under the terms and conditions of your licensed Apple developer program.

