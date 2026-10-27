# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cargo desktop toolchain-funcs xdg

DESCRIPTION="Modern Tauri/React desktop client for the Mumble voice chat platform"
HOMEPAGE="https://github.com/Fancy-Mumble/FancyMumble"

MY_PV="${PV/_beta/-beta.}"
SRC_URI="https://github.com/Fancy-Mumble/FancyMumble/archive/refs/tags/v${MY_PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/FancyMumble-${MY_PV}"

# Project itself is MIT; the license list of bundled crates/npm modules is
# approximate and should be audited.
LICENSE="MIT Apache-2.0 BSD BSD-2 ISC MPL-2.0 Unicode-3.0 ZLIB"
SLOT="0"
KEYWORDS="~amd64"

# Crates (incl. the git fork of cros-libva) and npm modules are downloaded
# at unpack time from Cargo.lock / package-lock.json.
RESTRICT="network-sandbox mirror test"

RDEPEND="
	dev-libs/glib:2
	media-libs/alsa-lib
	media-libs/libva:=
	media-libs/opus
	net-libs/libsoup:3.0
	net-libs/webkit-gtk:4.1
	gnome-base/librsvg:2
	x11-libs/gtk+:3
	dev-libs/libayatana-appindicator
	x11-libs/libxcb
"
DEPEND="${RDEPEND}"
BDEPEND="
	>=dev-lang/rust-1.88
	>=net-libs/nodejs-22[npm]
	dev-vcs/git
	llvm-core/clang
	dev-util/patchelf
	virtual/pkgconfig
"

QA_FLAGS_IGNORED="usr/bin/fancy-mumble"

src_unpack() {
	default

	export CARGO_HOME="${WORKDIR}/cargo_home"

	cd "${S}" || die
	einfo "Fetching Rust crates"
	cargo fetch --locked || die "cargo fetch failed"

	einfo "Fetching npm modules"
	cd crates/mumble-tauri/ui || die
	npm ci --ignore-scripts --no-audit --no-fund --cache "${WORKDIR}/npm_cache" \
		|| die "npm ci failed"
}

src_compile() {
	export CARGO_HOME="${WORKDIR}/cargo_home"
	tc-export CC CXX

	pushd crates/mumble-tauri/ui >/dev/null || die
	npm run build || die "UI build failed"
	popd >/dev/null || die

	# Upstream recommends this feature set for distro packages: no self-updater
	cargo build --release --locked --offline \
		--jobs "$(makeopts_jobs)" \
		-p mumble-tauri \
		--no-default-features --features custom-protocol \
		|| die "cargo build failed"
}

src_install() {
	newbin target/release/mumble-tauri fancy-mumble

	newicon -s 512 crates/mumble-tauri/icons/icon.png fancy-mumble.png
	make_desktop_entry fancy-mumble "Fancy Mumble" fancy-mumble \
		"Network;Chat;AudioVideo;"

	dodoc README.md
}
