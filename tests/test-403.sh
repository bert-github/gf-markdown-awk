:
# https://github.github.com/gfm/#example-403

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
**Gomphocarpus (*Gomphocarpus physocarpus*, syn.
*Asclepias physocarpa*)**
EOF

cat >$EXPECT <<EOF
<p><strong>Gomphocarpus (<em>Gomphocarpus physocarpus</em>, syn.
<em>Asclepias physocarpa</em>)</strong></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
