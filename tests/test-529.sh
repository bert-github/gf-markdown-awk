:
# https://github.github.com/gfm/#example-529

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
![[[foo](uri1)](uri2)](uri3)
EOF

cat >$EXPECT <<EOF
<p><img src="uri3" alt="[foo](uri2)" /></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
