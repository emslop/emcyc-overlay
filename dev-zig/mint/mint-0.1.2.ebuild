# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

ZIG_SLOT="0.17"
inherit zig

DESCRIPTION="Opinionated code formatter for Zig"
HOMEPAGE="https://github.com/ziord/mint"
SRC_URI="https://github.com/ziord/mint/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
