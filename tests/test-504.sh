:
# https://github.github.com/gfm/#example-504

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
[a](<b)c
[a](<b)c>
[a](<b>c)
EOF

cat >$EXPECT <<EOF
<p>[a](&lt;b)c
[a](&lt;b)c&gt;
[a](<b>c)</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
