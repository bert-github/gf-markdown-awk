:
# https://github.github.com/gfm/#example-441

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
**foo *bar **baz**
bim* bop**
EOF

cat >$EXPECT <<EOF
<p><strong>foo <em>bar <strong>baz</strong>
bim</em> bop</strong></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
