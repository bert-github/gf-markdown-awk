:
# https://github.github.com/gfm/#example-230

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
>     code

>    not code
EOF

cat >$EXPECT <<EOF
<blockquote>
<pre><code>code
</code></pre>
</blockquote>
<blockquote>
<p>not code</p>
</blockquote>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
