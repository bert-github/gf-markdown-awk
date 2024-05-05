:
# https://github.github.com/gfm/#example-623

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
Visit www.commonmark.org/help for more information.
EOF

cat >$EXPECT <<EOF
<p>Visit <a href="http://www.commonmark.org/help">www.commonmark.org/help</a> for more information.</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
