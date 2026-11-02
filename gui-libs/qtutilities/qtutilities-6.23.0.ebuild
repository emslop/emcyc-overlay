# Copyright 2025-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.85.0"

CRATES="
	aho-corasick@1.1.5
	anstream@1.0.0
	anstyle@1.0.14
	anstyle-parse@1.0.0
	anstyle-query@1.1.5
	anstyle-wincon@3.0.11
	clap@4.6.7
	clap_builder@4.6.7
	clap_derive@4.6.7
	clap_lex@1.1.1
	colorchoice@1.0.5
	heck@0.5.0
	is_terminal_polyfill@1.70.2
	memchr@2.8.3
	once_cell_polyfill@1.70.2
	proc-macro2@1.0.107
	quote@1.0.47
	regex@1.13.1
	regex-automata@0.4.18
	regex-syntax@0.8.11
	strsim@0.11.1
	syn@3.0.9
	unicode-ident@1.0.27
	utf8parse@0.2.2
	windows-link@0.2.1
	windows-sys@0.61.2
"

inherit cargo cmake multibuild virtualx

DESCRIPTION="Useful Qt related C++ classes and routines"
HOMEPAGE="https://github.com/Martchus/qtutilities"

SRC_URI="
	https://github.com/Martchus/qtutilities/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${CARGO_CRATE_URIS}
"

LICENSE="GPL-2"
# Dependent crates (icontool)
LICENSE+=" Apache-2.0 MIT Unicode-3.0"
SLOT="0/$(ver_cut 1)"
KEYWORDS="~amd64"
IUSE="test"
RESTRICT="!test? ( test )"

RDEPEND="
	dev-cpp/cpp-utilities
	dev-qt/qtbase:6[dbus,gui,widgets]
	dev-qt/qttools:6[linguist]
"
DEPEND="${RDEPEND}"
BDEPEND="dev-util/corrosion"

QA_FLAGS_IGNORED="usr/libexec/.*"

pkg_setup() {
	MULTIBUILD_VARIANTS=( qt6 )
	rust_pkg_setup
}

src_unpack() {
	cargo_src_unpack
}

multibuild_src_configure() {
	local mycmakeargs=(
		-DCONFIGURATION_NAME="${MULTIBUILD_VARIANT}"
		-DCONFIGURATION_TARGET_SUFFIX="${MULTIBUILD_VARIANT}"
		-DEXCLUDE_TESTS_FROM_ALL=$(usex !test)
	)
	case "${MULTIBUILD_VARIANT}" in
		qt6) mycmakeargs+=( -DQT_PACKAGE_PREFIX=Qt6 ) ;;
	esac
	cmake_src_configure
}

src_configure() {
	# cargo is invoked by Corrosion from CMake: stay offline, use vendored crates
	export CARGO_NET_OFFLINE=true
	multibuild_foreach_variant multibuild_src_configure
}

src_compile() {
	multibuild_foreach_variant cmake_src_compile
}

src_test() {
	virtx multibuild_foreach_variant cmake_src_test
}

src_install() {
	multibuild_foreach_variant cmake_src_install
}
