.PHONY: check check-patches check-patches-24.04 check-patches-26.04 build build-24.04 build-26.04 bundle

check:
	./tests/check.sh

check-patches: check-patches-24.04 check-patches-26.04

check-patches-24.04:
	./scripts/check-patches.sh 24.04

check-patches-26.04:
	./scripts/check-patches.sh 26.04

build: build-24.04 build-26.04

build-24.04:
	./scripts/build-strongswan.sh 24.04

build-26.04:
	./scripts/build-strongswan.sh 26.04

bundle:
	./scripts/create-bundle.sh
