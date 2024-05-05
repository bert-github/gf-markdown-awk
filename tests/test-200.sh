:
# https://github.github.com/gfm/#example-200

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
| f\\|oo  |
| ------ |
| b \`\\|\` az |
| b **\\|** im |
EOF

cat >$EXPECT <<EOF
<table>
<thead>
<tr>
<th>f|oo</th>
</tr>
</thead>
<tbody>
<tr>
<td>b <code>|</code> az</td>
</tr>
<tr>
<td>b <strong>|</strong> im</td>
</tr>
</tbody>
</table>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
