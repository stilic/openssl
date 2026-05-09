#!/usr/bin/env sh

set -eu

OPENSSL_VERSION="$1"
OPENSSL_SRC="https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"

OUTDIR="$PWD/output"
ORIGINAL_LIST="$OUTDIR/original_list"

TMPDIR="$(mktemp -d)"

mkdir -p "$OUTDIR"

cd "$TMPDIR"

curl -L "$OPENSSL_SRC" > out.tar.gz

SHA256="$(sha256sum out.tar.gz | awk '{print $1}')"

[ "$SHA256" = "$2" ] || {
    echo "sha256 '$SHA256' != '$2'"
    exit 1
}

tar xf out.tar.gz
rm out.tar.gz

cd "openssl-$OPENSSL_VERSION"

# Make the generated Makefile use host toolchain
patch -p1 < "$OUTDIR/../host-toolchain.patch"

sed -i \
    -e '/util\/write-man-symlinks/d' \
    -e 's|@$(PERL) $(SRCDIR)/util/mkdir-p.pl|@-mkdir -p|' \
    Configurations/unix-Makefile.tmpl

find . -type f ! \( -name libcrypto.num -o -name libssl.num \) > "$ORIGINAL_LIST"

env -i PATH=/usr/bin ./Configure \
    --prefix=/usr \
    --openssldir=/etc/ssl \
    --libdir=lib \
    no-unit-test \
    no-makedepend \
    shared \
    no-asm \
    linux-x86_64

env -i PATH=/usr/bin make build_all_generated -j"$(nproc)"

while read -r file; do
    rm -f "$file"
done < "$ORIGINAL_LIST"

rm "$ORIGINAL_LIST"

tar c . | gzip > "$OUTDIR/openssl-$OPENSSL_VERSION-generated.tar.gz"

cd "$OUTDIR"
rm -rf "$TMPDIR"
