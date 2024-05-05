:
# https://github.github.com/gfm/#example-122

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
<DIV CLASS="foo">

*Markdown*

</DIV>
EOF

cat >$EXPECT <<EOF
<DIV CLASS="foo">
<p><em>Markdown</em></p>
</DIV>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
