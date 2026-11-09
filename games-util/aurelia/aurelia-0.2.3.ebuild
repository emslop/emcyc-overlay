# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cargo toolchain-funcs

DESCRIPTION="Headless command-line Steam client and library manager written in Rust"
HOMEPAGE="https://github.com/Drackrath/Aurelia"
SRC_URI="https://github.com/Drackrath/Aurelia/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/Aurelia-${PV}"

# Project itself is GPL-3; the license list of bundled crates is
# approximate and should be audited.
LICENSE="GPL-3 Apache-2.0 BSD BSD-2 ISC MIT MPL-2.0 Unicode-3.0 ZLIB"
SLOT="0"
KEYWORDS="~amd64"

# Crates (incl. the git-pinned steam-vent) are downloaded at unpack time
# from Cargo.lock.
RESTRICT="network-sandbox mirror test"

RDEPEND="
	dev-libs/openssl:=
	sys-apps/dbus
	app-arch/xz-utils
"
DEPEND="${RDEPEND}"
BDEPEND="
	>=dev-lang/rust-1.85
	dev-vcs/git
	virtual/pkgconfig
"

QA_FLAGS_IGNORED="usr/bin/aurelia"

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
	dobin target/release/aurelia

	dodoc README.md
}
