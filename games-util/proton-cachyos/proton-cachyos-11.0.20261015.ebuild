# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 linux-info toolchain-funcs

MY_PV="${PV%.*}-${PV##*.}"

GECKO_PV="2.47.4"
MONO_PV="11.3.0"
XALIA_PV="0.5.0"
ZLUDA_PV="v7-preview.15"
ZLUDA_SHA="86ec0a9"

DESCRIPTION="Proton for Steam Play with extra CachyOS flavour, compiled from source"
HOMEPAGE="https://github.com/CachyOS/proton-cachyos"
SRC_URI="
	https://dl.winehq.org/wine/wine-gecko/${GECKO_PV}/wine-gecko-${GECKO_PV}-x86.tar.xz
	https://dl.winehq.org/wine/wine-gecko/${GECKO_PV}/wine-gecko-${GECKO_PV}-x86_64.tar.xz
	https://github.com/madewokherd/wine-mono/releases/download/wine-mono-${MONO_PV}/wine-mono-${MONO_PV}-x86.tar.xz
	https://github.com/madewokherd/xalia/releases/download/xalia-${XALIA_PV}/xalia-${XALIA_PV}-net48-mono.zip
	https://github.com/vosen/ZLUDA/releases/download/${ZLUDA_PV}/zluda-windows-${ZLUDA_SHA}.zip
"
EGIT_REPO_URI="https://github.com/CachyOS/proton-cachyos.git"
S="${WORKDIR}/${P}"

LICENSE="BSD LGPL-2.1+ MIT ZLIB all-rights-reserved"
SLOT="0"
KEYWORDS="~amd64"

IUSE="+slr native"
REQUIRED_USE="^^ ( slr native )"

# x86-64 microarchitecture levels and their CPU_FLAGS_X86 components.
# The build selects the highest complete level available; a missing optional
# flag simply falls back to the next lower level.
_V4_FLAGS=( avx512f avx512bw avx512cd avx512dq avx512vl )
_V3_FLAGS=( avx avx2 bmi1 bmi2 f16c fma3 )
_V2_FLAGS=( cx16 lahf_lm popcnt sse3 sse4_1 sse4_2 ssse3 )
_V1_FLAGS=( mmx sse sse2 )

for _f in "${_V4_FLAGS[@]}" "${_V3_FLAGS[@]}" "${_V2_FLAGS[@]}" "${_V1_FLAGS[@]}"; do
	IUSE+=" cpu_flags_x86_${_f}"
done
unset _f

# Submodules are cloned and crates/container images are pulled while building.
RESTRICT="mirror strip test network-sandbox"
QA_PREBUILT="*"

RDEPEND="
	app-arch/xz-utils
	dev-lang/python
	slr? ( || ( games-util/steam-launcher games-util/umu-launcher ) )
	native? (
		media-libs/vulkan-loader[abi_x86_32]
		media-libs/freetype
		media-libs/fontconfig
		media-libs/libpulse
		media-video/pipewire
		x11-libs/libX11
		x11-libs/libxkbcommon
		dev-libs/wayland
		games-util/umu-launcher
	)
"
# Package atoms below follow the Arch makedepends of proton-cachyos-native
# and still have to be checked against the current ::gentoo tree.
BDEPEND="
	dev-build/cmake
	dev-build/meson
	dev-lang/nasm
	dev-lang/rust
	dev-util/glslang
	dev-util/vulkan-headers
	dev-vcs/git
	llvm-core/clang
	llvm-core/lld
	media-gfx/fontforge
	net-misc/rsync
	app-arch/unzip
	dev-python/pefile
	dev-python/setuptools-scm
	dev-util/mingw64-toolchain[abi_x86_32]
	slr? ( app-containers/podman )
"

CONFIG_CHECK="~NTSYNC"

# Return success when every flag in $1 is enabled.
_proton_flags_enabled() {
	local flag
	for flag in "$@"; do
		use cpu_flags_x86_${flag} || return 1
	done
	return 0
}

pkg_pretend() {
	use amd64 || die "Only amd64 is supported"
}

src_unpack() {
	local tag="cachyos-${MY_PV}"
	local -a skip=( FEX piper openfst kaldi vosk-api zluda-libs/rocm-systems )
	if use native; then
		tag+="-native"
		skip+=(
			steam-audio/steam-audio steam-audio/pffft steam-audio/zlib
			steam-audio/libmysofa steam-audio/flatbuffers
			steamrtdeps/libxml2 steamrtdeps/libxkbcommon steamrtdeps/wayland-protocols
			steamrtdeps/libpcap steamrtdeps/libwebp steamrtdeps/xz steamrtdeps/speex
			steamrtdeps/speexdsp steamrtdeps/flac
		)
	else
		tag+="-slr"
	fi

	EGIT_COMMIT="${tag}"
	EGIT_CHECKOUT_DIR="${S}"
	EGIT_SUBMODULES=( '*' "${skip[@]/#/-}" )
	git-r3_src_unpack

	if use native; then
		# Same as the Arch PKGBUILD: gst-plugins-rs crates are fetched up front.
		export CARGO_HOME="${WORKDIR}/cargo_home"
		pushd "${S}/gst-plugins-rs" >/dev/null || die
		cargo fetch --locked --target x86_64-unknown-linux-gnu || die "cargo fetch failed"
		popd >/dev/null || die
	fi
}

src_prepare() {
	default

	mkdir -p "${S}/contrib" || die
	cp "${DISTDIR}"/wine-gecko-${GECKO_PV}-x86{,_64}.tar.xz \
		"${DISTDIR}"/wine-mono-${MONO_PV}-x86.tar.xz \
		"${DISTDIR}"/xalia-${XALIA_PV}-net48-mono.zip \
		"${DISTDIR}"/zluda-windows-${ZLUDA_SHA}.zip \
		"${S}/contrib/" || die

	if use native; then
		# Unprefixed-triplet wrappers so the Proton build system can use host
		# gcc for both i686 and x86_64 without the Steam Runtime container.
		local w="${WORKDIR}/wrappers" ccache_bin
		mkdir -p "${w}" || die
		ccache_bin="$(type -P ccache)"
		local -A bits=( [i686]="-m32 -melf_i386 --32 elf32-i386" [x86_64]="-m64 -melf_x86_64 --64 elf64-x86-64" )
		local a m32 ld as strip t
		for a in i686 x86_64; do
			read -r m32 ld as strip <<<"${bits[${a}]}"
			for t in ar ranlib nm; do
				ln -s "$(type -P gcc-${t})" "${w}/${a}-pc-linux-gnu-${t}" || die
			done
			for t in gcc g++; do
				printf '#!/bin/sh\nexec %s %s %s "$@"\n' "${ccache_bin}" "$(type -P ${t})" "${m32}" \
					> "${w}/${a}-pc-linux-gnu-${t}" || die
			done
			printf '#!/bin/sh\nexec %s %s "$@"\n' "$(type -P ld)" "${ld}" > "${w}/${a}-pc-linux-gnu-ld" || die
			printf '#!/bin/sh\nexec %s %s "$@"\n' "$(type -P as)" "${as}" > "${w}/${a}-pc-linux-gnu-as" || die
			printf '#!/bin/sh\nexec %s -F %s "$@"\n' "$(type -P strip)" "${strip}" > "${w}/${a}-pc-linux-gnu-strip" || die
		done
		chmod +x "${w}"/* || die
	fi
}

src_configure() {
	# Select the highest complete x86-64 level supported by CPU_FLAGS_X86.
	# GCC accepts x86-64-v1 through x86-64-v4; the baseline is plain x86-64.
	local march="x86-64"
	if _proton_flags_enabled "${_V1_FLAGS[@]}"; then
		march="x86-64-v1"
	fi
	if _proton_flags_enabled "${_V2_FLAGS[@]}"; then
		march="x86-64-v2"
	fi
	if _proton_flags_enabled "${_V3_FLAGS[@]}"; then
		march="x86-64-v3"
	fi
	if _proton_flags_enabled "${_V4_FLAGS[@]}"; then
		march="x86-64-v4"
	fi

	einfo "Building Proton-CachyOS for ${march}"

	# Portage's CFLAGS are deliberately replaced so all components target the
	# selected microarchitecture level.
	export CFLAGS="-O3 -march=${march} -mtune=generic"
	export CXXFLAGS="${CFLAGS}"
	export RUSTFLAGS="-C opt-level=3 -C target-cpu=${march}"
	export LDFLAGS="-Wl,-O1,--sort-common,--as-needed"

	mkdir -p "${WORKDIR}/build" || die
	cd "${WORKDIR}/build" || die

	local -a args=( --build-name="${PN}" )
	if use native; then
		export PATH="${WORKDIR}/wrappers:${PATH}"
		export CARGO_HOME="${WORKDIR}/cargo_home"
		args+=(
			--container-engine=none
			--proton-sdk-image=
			--enable-wow64
			--without-zluda-libs=rocm-systems
			--without-steamrt-depends
			--without-tts
		)
		ROOTLESS_CONTAINER="" "${S}/configure.sh" "${args[@]}" || die "configure.sh failed"
	else
		args+=( --container-engine=podman --enable-wow64 --without-tts --without-zluda-libs=rocm-systems )
		"${S}/configure.sh" "${args[@]}" || die "configure.sh failed"
	fi
}

src_compile() {
	cd "${WORKDIR}/build" || die
	use native && export PATH="${WORKDIR}/wrappers:${PATH}" CARGO_HOME="${WORKDIR}/cargo_home"
	SUBJOBS="$(makeopts_jobs)" emake -j1 dist

	local name="${PN}-${MY_PV}"
	cat > dist/compatibilitytool.vdf <<-EOF || die
	"compatibilitytools"
	{
	  "compat_tools"
	  {
	    "${PN}"
	    {
	      "install_path" "."
	      "display_name" "${name} ($(usex native native slr), ${march})"
	      "from_oslist"  "windows"
	      "to_oslist"    "linux"
	    }
	  }
	}
	EOF
}

src_install() {
	local dest="/usr/share/steam/compatibilitytools.d/${PN}"
	dodir "${dest}"
	cp -a "${WORKDIR}"/build/dist/. "${ED}${dest}/" || die

	insinto /usr/lib/modules-load.d
	newins - 10-${PN}.conf <<<"ntsync"
}
