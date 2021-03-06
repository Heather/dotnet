# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6
# !!! Unable to do any operations on 'dev-dotnet/dryioc-2.1.0-r201512110',
# !!! since its EAPI is higher than this portage version's. Please upgrade
# !!! to a portage version that supports EAPI '6'.
# 2015-11-17, portage-2.2.25 has been committed and it comes with complete EAPI 6 support
# https://archives.gentoo.org/gentoo-dev/message/73cc181e4949b88abfbd68f8a8ca9254

inherit versionator vcs-snapshot dotnet nupkg

HOMEPAGE="https://bitbucket.org/dadhi/dryioc"
DESCRIPTION="fast, small, full-featured IoC Container for .NET"
LICENSE="MIT"
LICENSE_URL="https://bitbucket.org/dadhi/dryioc/src/tip/LICENSE.txt"
SLOT="0"
KEYWORDS="~amd64 ~x86"

# debug = debug configuration (symbols and defines for debugging)
# developer = generate symbols information (to view line numbers in stack traces, either in debug or release configuration)
# test = allow NUnit tests to run
# nupkg = create .nupkg file from .nuspec
# gac = install into gac
# pkg-config = register in pkg-config database
IUSE="net45 debug developer test +nupkg +gac +pkg-config"
USE_DOTNET="net45"

COMMON_DEPEND=">=dev-lang/mono-4.0.2.5
"

RDEPEND="${COMMON_DEPEND}
"

DEPEND="${COMMON_DEPEND}
	test? ( dev-dotnet/nunit:2[nupkg] )
	virtual/pkgconfig
"

NAME=DryIoc
REPOSITORY_NAME="dadhi/dryioc"
REPOSITORY_URL="https://bitbucket.org/dadhi/dryioc"
EHG_REVISION="9f1954dd921acc432c22f1feff108c4d7ff87ffd"
HG_COMMIT="${EHG_REVISION:0:8}"

# PF 	Full package name, ${PN}-${PVR}, for example vim-6.3-r1
SRC_URI="${REPOSITORY_URL}/get/${HG_COMMIT}.tar.gz -> ${PF}.tar.gz
	mirror://gentoo/mono.snk.bz2"

#METAFILETOBUILD="DryIoc.sln"
METAFILETOBUILD="DryIoc/DryIoc.csproj"
NUSPEC_FILE_NAME=DryIoc.nuspec

# get_version_component_range is from inherit versionator
# PR 	Package revision, or r0 if no revision exists.
NUSPEC_VERSION=$(get_version_component_range 1-3)"${PR//r/.}"
#ICON_URL="https://bitbucket.org/account/dadhi/avatar/256/?ts=1451481107"
#ICON_URL="https://raw.githubusercontent.com/ArsenShnurkov/dotnet/dryioc/dev-dotnet/dryioc/files/icon.png"
ICON_URL="https://raw.githubusercontent.com/gentoo/dotnet/master/dev-dotnet/dryioc/files/icon.png"

# rm -rf /var/tmp/portage/dev-dotnet/dryioc-*
# emerge -v =dryioc-2.1.0-r201512110
# leafpad /var/tmp/portage/dev-dotnet/dryioc-2.1.0-r201512110/temp/build.log &

S=${WORKDIR}/dadhi-dryioc-${EHG_REVISION:0:12}

src_unpack()
{
	default
	rm "${S}/.nuget/NuGet.exe" || die
}

src_prepare() {
	default
	# /var/tmp/portage/dev-dotnet/dryioc-2.1.0-r201512110/work/dadhi-dryioc-9f1954dd921a
	einfo "patching project files"
	eapply "${FILESDIR}/DryIoc.csproj.patch"
	if ! use test ; then
		einfo "removing unit tests from solution"
	fi

	einfo "restoring packages (NUnit)"
	enuget_restore "${METAFILETOBUILD}"

	cp "${FILESDIR}/${NUSPEC_FILE_NAME}" "${S}/${NUSPEC_FILE_NAME}" || die
	patch_nuspec_file "${S}/${NUSPEC_FILE_NAME}"
}

src_configure() {
	:;
}

src_compile() {
	exbuild /p:SignAssembly=true "/p:AssemblyOriginatorKeyFile=${WORKDIR}/mono.snk" "${METAFILETOBUILD}"

	# run nuget_pack
	einfo "setting .nupkg version to ${NUSPEC_VERSION}"
	enuspec -Prop "version=${NUSPEC_VERSION};package_iconUrl=${ICON_URL}" "${S}/${NUSPEC_FILE_NAME}"
}

src_test() {
	default
}

src_install() {
	enupkg "${WORKDIR}/${NAME}.${NUSPEC_VERSION}.nupkg"

	egacinstall "bin/${DIR}/DryIoc.dll"

	install_pc_file
}

patch_nuspec_file()
{
	if use nupkg; then
		if use debug; then
			DIR="Debug"
FILES_STRING=`cat <<-EOF || die "${DIR} files at patch_nuspec_file()"
	<files> <!-- https://docs.nuget.org/create/nuspec-reference -->
		<file src="bin/${DIR}/DryIoc.dll" target="lib\net45\" />
		<file src="bin/${DIR}/DryIoc.dll.mdb" target="lib\net45\" />
	</files>
EOF
`
	else
		DIR="Release"
FILES_STRING=`cat <<-EOF || die "${DIR} files at patch_nuspec_file()"
	<files> <!-- https://docs.nuget.org/create/nuspec-reference -->
		<file src="bin/${DIR}/DryIoc.dll" target="lib\net45\" />
	</files>
EOF
`
		fi

		einfo ${FILES_STRING}
		replace "</package>" "${FILES_STRING}</package>" -- $1 || die "replace at patch_nuspec_file()"
	fi
}

PC_FILE_NAME=${PN}

install_pc_file()
{
	if use pkg-config; then
		dodir /usr/$(get_libdir)/pkgconfig
		ebegin "Installing ${PC_FILE_NAME}.pc file"
		sed \
			-e "s:@LIBDIR@:$(get_libdir):" \
			-e "s:@PACKAGENAME@:${PC_FILE_NAME}:" \
			-e "s:@DESCRIPTION@:${DESCRIPTION}:" \
			-e "s:@VERSION@:${PV}:" \
			-e 's*@LIBS@*-r:${libdir}'"/mono/${PC_FILE_NAME}/DryIoc.dll"'*' \
			<<\EOF >"${D}/usr/$(get_libdir)/pkgconfig/${PC_FILE_NAME}.pc" || die
prefix=${pcfiledir}/../..
exec_prefix=${prefix}
libdir=${exec_prefix}/@LIBDIR@
Name: @PACKAGENAME@
Description: @DESCRIPTION@
Version: @VERSION@
Libs: @LIBS@
EOF

		einfo PKG_CONFIG_PATH="${D}/usr/$(get_libdir)/pkgconfig/" pkg-config --exists "${PC_FILE_NAME}"
		PKG_CONFIG_PATH="${D}/usr/$(get_libdir)/pkgconfig/" pkg-config --exists "${PC_FILE_NAME}" || die ".pc file failed to validate."
		eend $?
	fi
}
