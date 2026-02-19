PREFIX ?= /usr/local

.PHONY: build release install clean workflow test test-unit test-integration

build:
	swift build

release:
	swift build -c release

install: release
	install -d $(PREFIX)/bin
	install .build/release/notif $(PREFIX)/bin/notif

clean:
	swift package clean
	rm -f Notif.alfredworkflow

workflow:
	cd alfred-workflow && zip -r ../Notif.alfredworkflow . -x ".*"

test: test-unit test-integration

test-unit: build
	swift run notif-test-unit

test-integration: build
	./test-integration.sh
