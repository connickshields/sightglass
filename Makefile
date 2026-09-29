APP_NAME := Sightglass
CONFIG ?= release
BUILD_DIR := build
APP := $(BUILD_DIR)/$(APP_NAME).app
PREFIX ?= /Applications
DEMO_DIR := $(BUILD_DIR)/demo

.PHONY: build test app run install demo run-demo clean

build:
	swift build -c $(CONFIG) --product $(APP_NAME)

test:
	swift test

app: build
	plutil -lint Support/Info.plist
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$$(swift build -c $(CONFIG) --show-bin-path)/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp Support/Info.plist "$(APP)/Contents/Info.plist"
	codesign --force --sign - "$(APP)"

run: app
	open "$(APP)"

install: app
	mkdir -p "$(PREFIX)"
	rm -rf "$(PREFIX)/$(APP_NAME).app"
	cp -R "$(APP)" "$(PREFIX)/"

demo:
	scripts/demo.sh "$(DEMO_DIR)"

run-demo: app
	SIGHTGLASS_CONFIG="$(CURDIR)/$(DEMO_DIR)/config.json" "$(APP)/Contents/MacOS/$(APP_NAME)"

clean:
	rm -rf .build "$(BUILD_DIR)"
