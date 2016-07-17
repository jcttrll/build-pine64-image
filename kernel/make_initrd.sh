#!/bin/sh
#
# Simple script to create a small busybox based initrd. It requires a compiled
# busybox static binary. You can also use any other initrd for example one
# from Debian like # https://d-i.debian.org/daily-images/arm64/20160206-00:06/netboot/debian-installer/arm64/
#
# Run this script with fakeroot or as root.

set -e

if [ $EUID -ne 0 ]; then
	exec fakeroot $0 "$@"
fi

unset BIN_FILES VERBOSE BUILD_DIR INIT
declare -a BIN_FILES

cleanup() {
	if [ -n "$BUILD_DIR" -a -d "$BUILD_DIR" ]; then
		rm -rf "$BUILD_DIR"
	fi
}

trap cleanup EXIT

fail() {
	echo "ERROR: $1" >&2
	exit 1
}

while [ $# -ne 0 ]; do
	arg="$1"
	case "$arg" in
		-i|--init)
			shift
			arg="$1"

			[ -z "$INIT" ] || fail "-i/--init can only be specificed once"

			[ -f "$arg" ] || fail "Argument to -b/--bin is not a file: $arg"
			[ -x "$arg" ] || fail "Argument to -b/--bin is not executable: $arg"

			INIT="$arg"
		;;
		-b|--bin)
			shift
			arg="$1"

			[ -f "$arg" ] || fail "Argument to -b/--bin is not a file: $arg"
			[ -x "$arg" ] || fail "Argument to -b/--bin is not executable: $arg"

			BIN_FILES+=("$arg")
		;;
		-v|--verbose)
			[ -z "$VERBOSE" ] || fail "-v/--verbose can only be specified once"

			VERBOSE=1
		;;
		*)
			fail "Unrecognized option: $arg"
		;;
	esac

	shift
done

if [ -z "$INIT" ]; then
	fail "init executable or script must be specified with required parameter -i/--init"
fi

BUILD_DIR=$(mktemp -d)

pushd "$BUILD_DIR" >/dev/null
mkdir -p bin dev proc sys tmp sbin
mknod dev/console c 5 1
popd >/dev/null

cp "$INIT" "$BUILD_DIR/init"

if [ ${#BIN_FILES[@]} -gt 0 ]; then
	if [ -n "$VERBOSE" ]; then echo "Files placed in /bin:"; fi

	for file in "${BIN_FILES[@]}"; do
		cp "$file" "$BUILD_DIR/bin/" || fail "Failed to copy file $file into /bin"
		if [ -n "$VERBOSE" ]; then echo "  $file"; fi
	done
fi

OUTPUT=$(readlink -f initrd.gz)

pushd "$BUILD_DIR" >/dev/null
find . | cpio -o -H newc -D "$BUILD_DIR" 2>/dev/null | gzip >"$OUTPUT"
popd >/dev/null
sync

