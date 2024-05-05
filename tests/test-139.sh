:
# https://github.github.com/gfm/#example-139

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
<pre language="haskell"><code>
import Text.HTML.TagSoup

main :: IO ()
main = print \$ parseTags tags
</code></pre>
okay
EOF

cat >$EXPECT <<EOF
<pre language="haskell"><code>
import Text.HTML.TagSoup

main :: IO ()
main = print \$ parseTags tags
</code></pre>
<p>okay</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
