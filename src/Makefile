# Agent Helm — build commands
#
# Run `make` for the help, or `make bootstrap` after a fresh clone.

.PHONY: help bootstrap project build test run clean

XCODE_DIR := /Applications/Xcode.app/Contents/Developer
PROJECT   := AgentHelm.xcodeproj
SCHEME    := AgentHelm

help:
	@echo "Targets:"
	@echo "  bootstrap   Generate the Xcode project (run once after clone)."
	@echo "  project     Regenerate the Xcode project from project.yml."
	@echo "  build       Build the .app via xcodebuild."
	@echo "  test        Run unit tests via xcodebuild."
	@echo "  run         Build and launch the .app."
	@echo "  clean       Remove DerivedData and the generated .xcodeproj."

bootstrap: project
	@echo "Done. Open AgentHelm.xcodeproj in Xcode, or run 'make build'."

project:
	@command -v xcodegen >/dev/null || { echo "xcodegen not installed. Run: brew install xcodegen"; exit 1; }
	xcodegen generate

build:
	DEVELOPER_DIR=$(XCODE_DIR) xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-destination 'platform=macOS' \
		build

test:
	DEVELOPER_DIR=$(XCODE_DIR) xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-destination 'platform=macOS' \
		test

run: build
	@APP=$$(DEVELOPER_DIR=$(XCODE_DIR) xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR =/ {print $$3}'); \
	open "$$APP/AgentHelm.app"

clean:
	rm -rf $(PROJECT)
	rm -rf ~/Library/Developer/Xcode/DerivedData/AgentHelm-*
