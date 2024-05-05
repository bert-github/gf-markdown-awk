:
# https://github.github.com/gfm/#example-205

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
| abc | def |
| --- | --- |
EOF

cat >$EXPECT <<EOF
<table>
<thead>
<tr>
<th>abc</th>
<th>def</th>
</tr>
</thead>
</table>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
