APP = build/Build/Products/Release/TraduzaJa.app
test: ; swift test
xcodeproj: ; xcodegen generate
build: xcodeproj
	xcodebuild -scheme TraduzaJa -configuration Release -derivedDataPath build -allowProvisioningUpdates -quiet
install: build
	-pkill -x TraduzaJa
	rm -rf /Applications/TraduzaJa.app && cp -R $(APP) /Applications/
run: install
	open /Applications/TraduzaJa.app
# Release assinada (Developer ID) + notarizada em dist/TraduzaJa-<versão>-mac.zip
release: ; scripts/release.sh
.PHONY: test xcodeproj build install run release
