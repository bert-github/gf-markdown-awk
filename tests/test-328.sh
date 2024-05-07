:
# https://github.github.com/gfm/#example-328
# Modified: Do not %-escape the URL

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
[foo](/f&ouml;&ouml; "f&ouml;&ouml;")
EOF

cat >$EXPECT <<EOF
<p><a href="/föö" title="föö">foo</a></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
