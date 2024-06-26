:
# https://github.github.com/gfm/#example-309
# Modified: Expanded tabs to spaces.

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
\\	\\A\\a\\ \\3\\φ\\«
EOF

cat >$EXPECT <<EOF
<p>\\   \\A\\a\\ \\3\\φ\\«</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
