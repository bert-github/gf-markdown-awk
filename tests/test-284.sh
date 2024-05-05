:
# https://github.github.com/gfm/#example-284

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
The number of windows in my house is
14.  The number of doors is 6.
EOF

cat >$EXPECT <<EOF
<p>The number of windows in my house is
14.  The number of doors is 6.</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
