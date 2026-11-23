# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cargo toolchain-funcs

DESCRIPTION="Terminal UI for browsing, installing, updating and launching Steam games via Aurelia"
HOMEPAGE="https://github.com/Drackrath/Aurelia-TUI"
SRC_URI="https://github.com/Drackrath/Aurelia-TUI/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/Aurelia-TUI-${PV}"

# Project itself is GPL-3; the license list of bundled crates is
# approximate and should be audited.
LICENSE="GPL-3 Apache-2.0 BSD BSD-2 ISC MIT MPL-2.0 Unicode-3.0 ZLIB"
SLOT="0"
KEYWORDS="~amd64"

# Crates are downloaded at unpack time from Cargo.lock.
RESTRICT="network-sandbox mirror test"

RDEPEND="
	>=games-util/aurelia-0.1.40
"
DEPEND="${RDEPEND}"
BDEPEND="
	>=dev-lang/rust-1.85
	virtual/pkgconfig
"

QA_FLAGS_IGNORED="usr/bin/aurelia-tui"

src_unpack() {
	default

	export CARGO_HOME="${WORKDIR}/cargo_home"

	cd "${S}" || die
	einfo "Fetching Rust crates"
	cargo fetch --locked || die "cargo fetch failed"
}

src_compile() {
	export CARGO_HOME="${WORKDIR}/cargo_home"
	tc-export CC CXX

	cargo build --release --locked --offline \
		--jobs "$(makeopts_jobs)" \
		|| die "cargo build failed"
}

src_install() {
	dobin target/release/aurelia-tui

	dodoc README.md
}
