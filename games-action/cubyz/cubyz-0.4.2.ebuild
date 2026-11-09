# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit multiprocessing

DESCRIPTION="An open-source voxel game with procedural terrain and modding support"
HOMEPAGE="https://github.com/PixelGuys/Cubyz"
SRC_URI="https://github.com/PixelGuys/Cubyz/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/Cubyz-${PV}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# Zig downloads its declared dependencies and the large asset package during
# the first build; Cubyz also has no meaningful offline test suite here.
RESTRICT="network-sandbox mirror test"

BDEPEND="
	=dev-lang/zig-0.16.0*
"

QA_FLAGS_IGNORED="usr/share/cubyz/bin/cubyz"

src_compile() {
	export ZIG_GLOBAL_CACHE_DIR="${T}/zig-global-cache"
	export ZIG_LOCAL_CACHE_DIR="${T}/zig-local-cache"

	zig build -Doptimize=ReleaseFast -Drelease=true \
		-j"$(makeopts_jobs)" \
		|| die "zig build failed"
}

src_install() {
	exeinto /usr/share/cubyz/bin
	newexe zig-out/bin/Cubyz cubyz

	insinto /usr/share/cubyz
	doins -r assets

	exeinto /usr/bin
	newexe "${FILESDIR}"/cubyz-launcher cubyz

	insinto /usr/share/applications
	doins "${FILESDIR}"/cubyz.desktop

	einstalldocs
}
