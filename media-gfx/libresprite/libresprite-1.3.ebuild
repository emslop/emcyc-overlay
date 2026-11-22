# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake xdg

DESCRIPTION="Animated sprite editor and pixel art tool"
HOMEPAGE="https://github.com/LibreSprite/LibreSprite"
SRC_URI="https://github.com/LibreSprite/LibreSprite/releases/download/v${PV}/SOURCE.CODE.%2B.submodules.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2 MIT OFL-1.1"
SLOT="0"
KEYWORDS="~amd64"

# Upstream's test targets need additional dependency/linkage integration.
RESTRICT="test"

RDEPEND="
	app-arch/libarchive:=
	dev-libs/tinyxml2:=
	media-libs/freetype:2
	media-libs/giflib:=
	media-libs/libpng:=
	media-libs/libsdl2[video]
	media-libs/libwebp:=
	media-libs/sdl2-image[png]
	net-misc/curl
	sys-libs/zlib
	virtual/jpeg:0
	x11-libs/libX11
	x11-libs/libXcursor
	x11-libs/libXext
	x11-libs/libXi
	x11-libs/libXpm
	x11-libs/libXxf86dga
	x11-libs/libXxf86vm
	x11-libs/libxcb:=
	x11-libs/pixman
"
DEPEND="${RDEPEND}"
BDEPEND="
	>=dev-build/cmake-4.1
	virtual/pkgconfig
"

DOCS=( README.md CONTRIBUTORS.md SCRIPTING.md Theming.md )

src_unpack() {
	# The release archive has no enclosing directory.
	mkdir -p "${S}" || die
	cd "${S}" || die
	unpack "${A}"
}

src_prepare() {
	# Respect the user's optimization and debugging flags.
	sed -i \
		-e '/set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O[03]/d' \
		-e '/set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O[03]/d' \
		-e '/set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -O[03]/d' \
		CMakeLists.txt || die

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DENABLE_MEMLEAK=OFF
		-DENABLE_TESTS=OFF
		-DRELEASE_TAG=ON
		-DRELEASE_VERSION="${PV}"
		-DUSE_SDL2_BACKEND=ON
		-DWITH_DESKTOP_INTEGRATION=ON
		-DWITH_GTK_FILE_DIALOG_SUPPORT=OFF
		-DWITH_QT_THUMBNAILER=OFF
		-DWITH_WEBP_SUPPORT=ON
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install

	# Do not ship the unsafe shared-/tmp thumbnail helper.
	rm "${ED}/usr/bin/libresprite-thumbnailer" \
		"${ED}/usr/share/thumbnailers/libresprite.thumbnailer" || die
}
