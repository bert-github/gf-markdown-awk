:
# https://github.github.com/gfm/#example-160

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
<table>

  <tr>

    <td>
      Hi
    </td>

  </tr>

</table>
EOF

cat >$EXPECT <<EOF
<table>
  <tr>
<pre><code>&lt;td&gt;
  Hi
&lt;/td&gt;
</code></pre>
  </tr>
</table>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
