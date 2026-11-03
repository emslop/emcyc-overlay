# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CRATES=""
inherit cargo

COMMIT="c7e34b3f61a14f6c9f78d72bed4f2546b3435096"

DESCRIPTION="Fast and beautiful Rust/Iced desktop client for Navidrome"
HOMEPAGE="https://github.com/f-o-o-g-s/nokkvi"
SRC_URI="
	https://github.com/f-o-o-g-s/nokkvi/archive/${COMMIT}.tar.gz
	-> ${P}.tar.gz
"
S="${WORKDIR}/${PN}-${COMMIT}"

LICENSE="GPL-3.0-only"
SLOT="0"
KEYWORDS="~amd64"

# Upstream pins Git dependencies in Cargo.toml; Cargo cannot resolve them
# from a registry vendor snapshot without a dedicated vendor tarball.
RESTRICT="network-sandbox"

RDEPEND="
	dev-libs/wayland
	media-libs/vulkan-loader
	x11-libs/libxkbcommon
"
BDEPEND="
	virtual/pkgconfig
	virtual/rust
"

QA_FLAGS_IGNORED="usr/bin/${PN}"

src_configure() {
	cargo_src_configure
}

src_compile() {
	cargo_src_compile
}

src_install() {
	cargo_src_install
}
