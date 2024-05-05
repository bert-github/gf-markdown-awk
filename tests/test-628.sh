:
# https://github.github.com/gfm/#example-628

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
www.commonmark.org/he<lp
EOF

cat >$EXPECT <<EOF
<p><a href="http://www.commonmark.org/he">www.commonmark.org/he</a>&lt;lp</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
