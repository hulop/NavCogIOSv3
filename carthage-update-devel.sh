#!/bin/sh

rm -rf ~/Library/Caches/org.carthage.CarthageKit/DerivedData/HLPDialog/
rm -rf ~/Library/Caches/org.carthage.CarthageKit/dependencies/HLPDialog/
rm -rf Carthage/
#carthage bootstrap --platform iOS
carthage update --platform iOS
