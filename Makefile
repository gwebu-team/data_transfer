SHELL:=/bin/bash
# ^^^ Use bash syntax, mitigates dash's printf on Debian
ver:=$(shell git describe --dirty --long --match='v[0-9]*.[0-9]*' | cut -c 2- | cut -d - -f 1,2,4)
rpm_ver:=$(firstword $(subst -, ,$(ver)))
rpm_rev:=$(subst $(rpm_ver)-,,$(ver))
# Fix "Illegal char '-' (0x2d) in: Release: "
rpm_rev:=$(subst -,_,$(rpm_rev))



help:
	@echo
	@echo "▍Help"
	@echo "▀▀▀▀▀▀"
	@echo
	@echo "Available targets:"
	@echo "    dist:               Create source distribution package in dist/."
	@echo "    rpm:                Create an RPM package."
	@echo "    podman_rpm          Create an RPM package using podman on MacOS."
	@echo "    lint:               Check shell script for syntax errors and style issues."
	
	@echo
	@echo "    clean:              Clean all generated files."
	@echo
	@echo "Version $(ver), rpm_ver=$(rpm_ver), rpm_rev=$(rpm_rev)."
.PHONY: help lint



.PHONY: dist
dist: dist/nc_transfer-$(rpm_ver).tar.xz



dist/nc_transfer-$(rpm_ver).tar.xz:
	test -d dist || mkdir dist
	sed 's/^Version: .*/Version: $(rpm_ver)/' < gwebu-transfer.spec.in \
		| sed 's/^Release: .*/Release: $(rpm_rev)/' \
		> gwebu-transfer.spec
	git archive --prefix="nc_transfer-$(rpm_ver)/" --add-file=gwebu-transfer.spec HEAD | xz -9 > "$@"
	rm gwebu-transfer.spec



.PHONY: rpm
rpm: dist
	rpmbuild -ta "dist/nc_transfer-$(rpm_ver).tar.xz"



.PHONY: lint
lint:
	@echo "Checking shell script syntax..."
	@bash -n nc_transfer.sh
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo "Running shellcheck..."; \
		shellcheck nc_transfer.sh; \
	else \
		echo "shellcheck not found, skipping style checks"; \
	fi

.PHONY: clean
clean:
	rm -rf dist



.PHONY: podman_rpm
podman_rpm: dist
	-podman stop build
	podman buildx build -t podman_rpm_build -f Dockerfile-build .  # --platform linux/amd64
	# Extract the RPMs from the container to ./dist/ locally.
	podman run --rm -d --name=build localhost/podman_rpm_build /usr/bin/bash -c "trap : TERM INT; sleep infinity & wait"
	podman cp build:../rpmbuild/RPMS/noarch/. ./dist/
	podman stop build
	podman image rm localhost/podman_rpm_build
