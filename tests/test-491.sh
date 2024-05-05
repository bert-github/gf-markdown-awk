:
# https://github.github.com/gfm/#example-491

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
~~Hi~~ Hello, ~there~ world!
EOF

cat >$EXPECT <<EOF
<p><del>Hi</del> Hello, <del>there</del> world!</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
