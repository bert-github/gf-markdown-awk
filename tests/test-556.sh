:
# https://github.github.com/gfm/#example-556

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
[foo][ref[bar]]

[ref[bar]]: /uri
EOF

cat >$EXPECT <<EOF
<p>[foo][ref[bar]]</p>
<p>[ref[bar]]: /uri</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
