:
# https://github.github.com/gfm/#example-279

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
- [ ] foo
- [x] bar
EOF

cat >$EXPECT <<EOF
<ul>
<li><input disabled="" type="checkbox"> foo</li>
<li><input checked="" disabled="" type="checkbox"> bar</li>
</ul>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
