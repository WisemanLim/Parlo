# Parlo — ios-swiftui. 프로젝트는 XcodeGen(project.yml) → Parlo.xcodeproj 로 생성.
.PHONY: dev test build deploy setup generate open run
SCHEME ?= Parlo
DEST ?= platform=iOS\ Simulator,name=iPhone\ 17\ Pro
generate: ; xcodegen generate                       # project.yml → Parlo.xcodeproj
open:   ; open Parlo.xcodeproj
dev:    ; xcodebuild -scheme $(SCHEME) -destination $(DEST) -configuration Debug build
test:   ; xcodebuild test -scheme $(SCHEME) -destination $(DEST)
run:    ; xcodebuild -scheme $(SCHEME) -destination $(DEST) -configuration Debug build && \
	  xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; \
	  open -a Simulator
build:  ; cd fastlane && fastlane ios build
deploy: ; cd fastlane && fastlane ios beta   # TestFlight

# 최초 1회 실행 / run once after scaffold
setup:
	@# 1) Xcode Command Line Tools
	@xcode-select -p > /dev/null 2>&1 || \
	  (echo "ERROR: Xcode CLT not installed. Run: xcode-select --install" && exit 1)
	@echo "[setup] Xcode CLT: $$(xcode-select -p)"
	@xcodebuild -version
	@# 2) 사용 가능한 시뮬레이터 확인 / list available simulators
	@echo "[setup] Available simulators (iOS):"
	@xcrun simctl list devices available | grep "iPhone" | head -8
	@# 3) Xcode 프로젝트 생성 (XcodeGen)
	@echo "[setup] Generating Parlo.xcodeproj (xcodegen)..."
	@xcodegen generate 2>/dev/null || echo "[setup] WARN: xcodegen 미설치 → brew install xcodegen"
	@echo "[setup] Done. Run: make dev  (또는 make open 으로 Xcode 열기)"
