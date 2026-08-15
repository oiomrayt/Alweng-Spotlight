.PHONY: build universal release install uninstall clean

build:
	./scripts/build.sh

universal:
	./scripts/build.sh --universal

release:
	./scripts/package-release.sh

install: build
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

clean:
	rm -rf .build dist
