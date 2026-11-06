# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

ZIG_SLOT="0.17"

declare -g -r -A ZBS_DEPENDENCIES=(
	[translate_c-2.0.0-Q_BUWltOBwBYABF84EUL208pIFeUIwbBs29FmVBaafN5.tar.gz]='https://deps.files.ghostty.org/translate_c-02ff0c523fb92a38939b04d0145c4a9602a74d56.tar.gz'
	[aro-0.0.0-JSD1QtuBNwCASyBtNF3pqTl_W3oAJQGEVyFAtrBSE_Pa.tar.gz]='https://codeberg.org/ziglang/arocc/archive/d0c8c4d9c55daa7ef6e40cf0f630a5b5e900989b.tar.gz'
	[uucode-0.2.0-ZZjBPoGFVgCiflJNFc6Io8xzC67B6PA5bUkk4LT0kCxg.tar.gz]='https://deps.files.ghostty.org/uucode-ea62149739404a73c202b48a33bf6dd2af4bd9b0.tar.gz'
	[N-V-__8AAGmZhABbsPJLfbqrh6JTHsXhY6qCaLAQyx25e0XE.tar.gz]='https://deps.files.ghostty.org/highway-66486a10623fa0d72fe91260f96c892e41aceb06.tar.gz'
	[N-V-__8AAP5JWgCGP_AD0teWpa4krRvE9VPZzvviGdbmN4jI.tar.gz]='https://deps.files.ghostty.org/wuffs-7411f488fe2e2c205c3d3b3d28638b7356522930.tar.gz'
	[N-V-__8AADYiAAB_80AWnH1AxXC0tql9thT-R-DYO1gBqTLc.tar.gz]='https://deps.files.ghostty.org/pixels-12207ff340169c7d40c570b4b6a97db614fe35e35.tar.gz'
)

inherit zig

GHOSTTY_VERSION="1.4.0"

DESCRIPTION="Ghostty's terminal emulation core as a C library (libghostty-vt)"
HOMEPAGE="https://ghostty.org/ https://github.com/ghostty-org/ghostty"
SRC_URI="
	https://github.com/ghostty-org/ghostty/archive/refs/tags/v${GHOSTTY_VERSION}.tar.gz -> ghostty-${GHOSTTY_VERSION}.tar.gz
	${ZBS_DEPENDENCIES_SRC_URI}
"
S="${WORKDIR}/ghostty-${GHOSTTY_VERSION}"

LICENSE="MIT Apache-2.0 BSD BSD-2 BSD-4 Boost-1.0 MPL-2.0 Unicode-3.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	!x11-terms/ghostty
"

BDEPEND="
	|| (
		>=dev-lang/zig-bin-0.17.0:${ZIG_SLOT}
		>=dev-lang/zig-0.17.0:${ZIG_SLOT}
	)
"

src_configure() {
	local my_zbs_args=(
		-fno-sys=simdutf
		-fno-sys=highway
		-Demit-lib-vt=true
		-Demit-themes=false
		-Demit-terminfo=false
		-Dapp-runtime=none
		-Di18n=false
		-Doptimize=fast
		-Dcpu=baseline
		-Dversion-string="${GHOSTTY_VERSION}"
		-Dlib-version-string=0.1.0-dev+83fb95624b0439ee660c2679b43b38c8b63769cd
		-Dstrip=false
	)
	zig_src_configure
}
