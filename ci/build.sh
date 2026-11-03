#!/bin/bash
# Builds the unsigned IPA, takes simulator screenshots, and (if GITHUB_TOKEN is set) publishes everything as a GitHub release.
set -u
cd "$(dirname "$0")/.."
X=$(ls -d /Applications/Xcode_26*.app /Applications/Xcode-26*.app 2>/dev/null | sort -V | tail -1); [ -n "$X" ] && sudo xcode-select -s "$X" 2>/dev/null
xcodebuild -version; sw_vers
command -v xcodegen >/dev/null || brew install xcodegen >/dev/null
xcodegen generate || exit 1
OK=1
xcodebuild -project Rayhan.xcodeproj -scheme Rayhan -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build > build.log 2>&1 || OK=0
grep -E "error:" build.log | sort -u > errors.txt
echo "device build ok=$OK, $(wc -l < errors.txt) error lines"; head -60 errors.txt
mkdir -p shots
if [ $OK = 1 ]; then
  rm -rf Payload; mkdir Payload; cp -R build/Build/Products/Release-iphoneos/Rayhan.app Payload/; zip -qry Rayhan.ipa Payload; ls -la Rayhan.ipa
  xcodebuild -project Rayhan.xcodeproj -scheme Rayhan -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath simbuild CODE_SIGNING_ALLOWED=NO build > simbuild.log 2>&1 && {
    APP=simbuild/Build/Products/Debug-iphonesimulator/Rayhan.app
    pick() { xcrun simctl list devices available | grep -E "$1" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'; }
    IPAD=$(pick "iPad Pro 13|iPad Pro \(12.9|iPad Air 13|iPad"); IPHONE=$(pick "iPhone 17 Pro \(|iPhone 1[6-9] Pro \(|iPhone")
    shoot() { DEV=$1; NAME=$2; shift 2; xcrun simctl terminate $DEV com.rayhanclinics.xray >/dev/null 2>&1; xcrun simctl launch $DEV com.rayhanclinics.xray "$@" >/dev/null; sleep 7; xcrun simctl io $DEV screenshot shots/$NAME.png >/dev/null 2>&1; }
    for DEV in $IPAD $IPHONE; do xcrun simctl boot $DEV 2>/dev/null; xcrun simctl bootstatus $DEV -b >/dev/null; xcrun simctl status_bar $DEV override --time "9:41" --batteryState charged --batteryLevel 100 2>/dev/null; xcrun simctl install $DEV $APP; done
    for S in signin reception calendar calweek calmonth patients profile chart xray labs labcase payments paybal paylate paylabs appointment cancel newpatient; do shoot $IPAD ipad_$S -demoScreen $S -demoLandscape YES; done
    for S in reception profile; do shoot $IPAD ipadP_$S -demoScreen $S; done
    for S in signin reception calendar patients profile labs payments; do shoot $IPHONE iphone_$S -demoScreen $S; done
    ls shots | wc -l
  } || echo "simulator build failed"
fi
zip -qr shots.zip shots build.log errors.txt $( [ -f simbuild.log ] && echo simbuild.log )
if [ -n "${GITHUB_TOKEN:-}" ]; then
  REPO=Bashicos/rayhan-ipad; TAG="build-$(date -u +%Y%m%d-%H%M%S)"; SHA=$(git rev-parse HEAD)
  NAME=$([ $OK = 1 ] && echo "Rayhan iPad app · $TAG" || echo "FAILED build · $TAG")
  REL=$(curl -sS -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" https://api.github.com/repos/$REPO/releases \
    -d "{\"tag_name\":\"$TAG\",\"target_commitish\":\"$SHA\",\"name\":\"$NAME\",\"body\":\"Unsigned IPA for Sideloadly. Commit $SHA\",\"prerelease\":$([ $OK = 1 ] && echo false || echo true)}")
  UP=$(echo "$REL" | python3 -c 'import sys,json; print(json.load(sys.stdin)["upload_url"].split("{")[0])')
  for F in shots.zip $( [ -f Rayhan.ipa ] && echo Rayhan.ipa ); do
    curl -sS -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/octet-stream" --data-binary @$F "$UP?name=$F" >/dev/null && echo "uploaded $F"
  done
fi
[ $OK = 1 ]
