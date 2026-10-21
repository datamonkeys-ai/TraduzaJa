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
.PHONY: test xcodeproj build install run
