:
# https://github.github.com/gfm/#example-331

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
\`f&ouml;&ouml;\`
EOF

cat >$EXPECT <<EOF
<p><code>f&amp;ouml;&amp;ouml;</code></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
