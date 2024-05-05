:
# https://github.github.com/gfm/#example-166

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
[foo]: /url 'title

with blank line'

[foo]
EOF

cat >$EXPECT <<EOF
<p>[foo]: /url 'title</p>
<p>with blank line'</p>
<p>[foo]</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
