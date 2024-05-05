:
# https://github.github.com/gfm/#example-599

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
![[foo]]

[[foo]]: /url "title"
EOF

cat >$EXPECT <<EOF
<p>![[foo]]</p>
<p>[[foo]]: /url &quot;title&quot;</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
