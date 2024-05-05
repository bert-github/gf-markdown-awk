:
# https://github.github.com/gfm/#example-525

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
[link *foo **bar** \`#\`*](/uri)
EOF

cat >$EXPECT <<EOF
<p><a href="/uri">link <em>foo <strong>bar</strong> <code>#</code></em></a></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
