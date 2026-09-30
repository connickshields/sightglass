APP_NAME := Sightglass
CONFIG ?= release
BUILD_DIR := build
APP := $(BUILD_DIR)/$(APP_NAME).app
PREFIX ?= /Applications
DEMO_DIR := $(BUILD_DIR)/demo

# Release builds set these on the command line. Left empty, the app keeps
# Support/Info.plist's version and build number, and builds for this Mac's
# architecture only. `:=` ignores same-named environment variables, such as
# the BUILD_NUMBER that CI systems export.
VERSION :=
BUILD_NUMBER :=
ARCHS :=
SWIFT_BUILD := swift build -c $(CONFIG) $(foreach arch,$(ARCHS),--arch $(arch))
ZIP := $(BUILD_DIR)/$(APP_NAME)-$(VERSION).zip

ifneq ($(filter zip,$(MAKECMDGOALS)),)
ifeq ($(VERSION),)
$(error usage: make zip VERSION=x.y.z [BUILD_NUMBER=n] [ARCHS="arm64 x86_64"])
endif
endif

.PHONY: build test app zip run install demo run-demo clean

build:
	$(SWIFT_BUILD) --product $(APP_NAME)

test:
	swift test

app: build
	plutil -lint Support/Info.plist
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$$($(SWIFT_BUILD) --show-bin-path)/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp Support/Info.plist "$(APP)/Contents/Info.plist"
	$(if $(VERSION),plutil -replace CFBundleShortVersionString -string "$(VERSION)" "$(APP)/Contents/Info.plist")
	$(if $(BUILD_NUMBER),plutil -replace CFBundleVersion -string "$(BUILD_NUMBER)" "$(APP)/Contents/Info.plist")
	codesign --force --sign - "$(APP)"

zip: app
	rm -f "$(ZIP)"
	ditto -c -k --keepParent "$(APP)" "$(ZIP)"

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
