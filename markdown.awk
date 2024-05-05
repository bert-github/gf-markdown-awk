# Library for converting GitHub-flavored markdown to HTML.
#
# Works with Gnu Awk. Here is an example of how to use this library to
# create a program that converts markdown to HTML:
#
#     @include "markdown.awk"
#     { lines = lines $0 "\n" }
#     END { printf "%s", markdown::to_html(lines) }
#
#
# More documentation:
#
# To use the library, put
#
#     @include "markdown.awk"
#
# in your Awk program. That makes the following functions available:
#
# markdown::to_html(string)
#
#     This function is given a string with markdown text and returns
#     an HTML fragment. It does not return a complete HTML document:
#     The returned fragment is meant to be put in the BODY of an HTML
#     document.
#
#     Example:
#
#        print markdown::to_html("### Heading 3\nPara 1")
#
#     yields
#
#        <h3>Heading 3</h3>
#        <p>Para 1</p>
#
# markdown::to_inline_html(string)
#
#     This function is given a string with markdown text and returns
#     an HTML fragment with only inline HTML. If the string contains
#     markdown for block elements, those are not interpreted and
#     treated as text.
#
#     Example:
#
#        print markdown::to_inline_html("Text with *emphasized words.*")
#
#     yields
#
#        Text with <em>emphasized words.</em>
#
# markdown::to_text(string)
#
#     This function is given a string with markdown text and returns
#     plain text with just the text content, after removing all
#     markup. The result is a plain text string, not an HTML string,
#     i.e., it may contain '<', '>', '&' and '"' characters which are
#     not escaped as HTML character entities. '&lt;', etc.
#
#     Example:
#
#        print markdown:to_text("### An *emphasized* heading")
#
#     yields
#
#        An emphasized heading
#
# markdown::version()
#
#     Returns the version of this library, currently "0.2".
#
#
# Copyright © 2023-2024 World Wide Web Consortium.
# See the file COPYING.
#
# Created: 28 May 2023
# Author: Bert Bos <bert@w3.org>

@include "htmlmathml.awk"

@namespace "markdown"


# version -- return the version number of this library
function version()
{
  return "0.2"
}


# to_html -- markdown to HTML
function to_html(s,	n, i, lines, stack, curblock, result)
{
  # Parse the markdown line by line.
  #
  sub(/\n$/, "", s)
  n = split(s, lines, /\n/)
  for (i = 1; i <= n; i++) {
    # printf "Next line: \"%s\"\n", lines[i] > "/dev/stderr"
    add_line_to_tree(stack, 1, expand_tabs(lines[i]), curblock, result)
  }
  close_blocks(stack, 1, curblock, result)
  return join(result)
}


# to_inline_html -- convert markdown to inline HTML
function to_inline_html(s,		t, n, i, x, replacements)
{
  s = inline(s, 0, replacements)

  # Replace the <n> tags in s by the corresponding code that was
  # stored in replacements. The replacements may themselves contain
  # further tags, so repeat until there are no more changes (n == 0).
  do {
    t = ""
    n = 0
    while ((i = match(s, /\002([0-9]+)\003/, x))) {
      # print "retrieve replacement " x[1] " -> " item(replacements, 0 + x[1]) > "/dev/stderr"
      t = t substr(s, 1, i - 1) item(replacements, 0 + x[1])
      s = substr(s, i + length(x[0]))
      n++
    }
    s = t s
  } while (n)

  return s
}


function inline(s, no_links, replacements,		result, t, i, x)
{
  # print "inline(\"" s "\", " no_links ",...)" > "/dev/stderr"

  # Replace occurrences in s of code spans (`...`), autolinks (<url>)
  # and HTML tags (elements, comments, CDATA sections, processing
  # instructions) by "<n>" tags and put the corresponding HTML code in
  # replacements at index n. The "<n>" tags actually consist of \002 +
  # decimal number + \003.
  t = ""
  while ((i = match(s, /(^|[^\\])(`|<)(.*)/, x)))
    if (inline_code_span(x[2] x[3], result, replacements) ||
	inline_autolink(x[2] x[3], no_links, result, replacements) ||
	inline_html_tag(x[2] x[3], result, replacements)) {
      t = t substr(s, 1, i - 1) x[1] result["html"]
      s = result["rest"]
    } else {
      t = t substr(s, 1, i - 1) x[1] x[2]
      s = x[3]
    }
  s = t s
  # print "after \"`\" and \"<\": \"" s "\"" > "/dev/stderr"

  # Replace occurences in s of links ("[anchor](url)") or images
  # ("![alt](url)") by "<n>" tags and put the corresponding HTML code
  # in replacements.
  t = ""
  while ((i = match(s, /(^|[^\\])(!?\[)(.*)/, x)))
    if (inline_link_or_image(x[2] x[3], no_links, result, replacements)) {
      t = t substr(s, 1, i - 1) x[1] result["html"]
      # print "so far: \"" t "\"" > "/dev/stderr"
      s = result["rest"]
    } else {
      t = t substr(s, 1, i - 1) x[1] x[2]
      s = x[3]
    }
  s = t s
  # print "after links: \"" s "\"" > "/dev/stderr"

  # Replace occurrences in s of bold (**...**, __...__) or italic
  # (*...*, _..._) with tags "<n>" and put the corresponding HTML code
  # in replacements.
  t = ""
  while ((i = match(s, /(^|[^\\])(_+|\*+)([^[:space:][:punct:]].*)|(^|[[:space:][:punct:]])(_+|\*+)([[:punct:]].*)/, x)))
    if (inline_emphasis(x[2] x[3]  x[5] x[6], no_links, result, replacements)) {
      t = t substr(s, 1, i - 1) x[1] x[4] result["html"]
      s = result["rest"]
    } else {
      t = t substr(s, 1, i - 1) x[1] x[2]  x[4] x[5]
      s = x[3] x[6]
    }
  s = t s
  # print "after * and _: \"" s "\"" > "/dev/stderr"

  # Replace occurrences in s of strikethrough (~...~, ~~...~~) with
  # tags "<n>" and put the corresponding HTML code in replacements.
  t = ""
  while ((i = match(s, /(^|[^~\\])(~~?)([^~].*)/, x)))
    if (inline_strikethrough(x[2] x[3], result, replacements)) {
      t = t substr(s, 1, i - 1) x[1] result["html"]
      s = result["rest"]
    } else {
      t = t substr(s, 1, i - 1) x[1] x[2]
      s = x[3]
    }
  s = t s
  # print "after ~: \"" s "\"" > "/dev/stderr"

  # Replace hard line breaks by <br> and remove backslash escapes.
  push(replacements, "<br />\n")
  t = "\002" size(replacements) "\003"
  s = awk::gensub(/ \n/, "\n", "g",
    awk::gensub(/(  +|\\)\n/, t, "g", esc_html(unesc_md(s))))

  return s
}


function inline_code_span(s, result, replacements,	x, content, t, n)
{
  # Check that s starts with a span of "`".
  if (! match(s, /^(`+)(.*)/, x)) return 0
  # Check that there is another span of "`" of equal length.
  if (! (i = match(x[2], "[^`]" x[1] "([^`]|$)"))) return 0
  # Replace newlines in the contents by spaces.
  content = awk::gensub(/\n/, " ", "g", substr(x[2], 1, i))
  # If there is a space both at start and end, remove it.
  if (content ~ /^ .*[^ ].* $/) content = substr(content, 2, i - 2)
  # Store HTML code in replacements.
  t = "<code>" esc_html(content) "</code>"
  push(replacements, t)
  n = size(replacements)
  # Return result.
  result["html"] = "\002" n "\003"
  result["rest"] = substr(x[2], i + length(x[1]) + 1)
  # print "Found inline code <" n "> = " t > "/dev/stderr"
  return 1
}


function inline_autolink(s, no_links, result,	replacements,	x, t, n)
{
  # print "inline_autolink(\"" s "\")" > "/dev/stderr"
  if (match(s, /^<([a-zA-Z][a-zA-Z0-0+.-]+:[^>[:space:]]+)>(.*)/, x)) {
    if (no_links) t = esc_html(x[1])
    else t = "<a href=\"" esc_html(esc_url(x[1])) "\">" esc_html(x[1]) "</a>"
  } else if (match(s, /^<([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>(.*)/, x)) {
    if (no_links) t = esc_html(x[1])
    else t = "<a href=\"mailto:" esc_html(x[1]) "\">" esc_html(x[1]) "</a>"
  } else {			# Neither URL nor email address
    return 0
  }
  push(replacements, t)		# Store the HTML code in replacements
  n = size(replacements)	# Get the index where it was stored
  result["html"] = "\002" n "\003" # The tag to replace the auutolink with
  result["rest"] = substr(s, length(x[0]) + 1)
  # print "Found autolink <" n "> = " t > "/dev/stderr"
  return 1
}


function inline_html_tag(s, result, replacements,	x, t, n)
{
  # print "inline_html_tag(\"" s "\",...)" > "/dev/stderr"
  if (((match(s, /^<([a-zA-Z][a-zA-Z0-9_-]*)(\s+[a-zA-Z0-9:_][a-zA-Z0-9_.:-]*(\s*=\s*([^[:space:]"'=<>`]+|"[^"]*"|'[^']*'))?)*\s*\/?>/, x) ||
	match(s, /^<\/([a-zA-Z][a-zA-Z0-9_-]*)\s*>/, x)) &&
       tolower(x[1]) !~ /^(title|textarea|style|xmp|iframe|noembed|noframes|script|plaintext)$/) ||
      match(s, /^<!\[CDATA\[([^\]]|\][^\]]|\]\][^>])*\]\]>/, x) ||
      match(s, /^<!--([^->]|-[^->])*-->/, x) ||
      match(s, /^<![a-zA-Z][^>]*>/, x) ||
      match(s, /^<\?([^?>]|\?[^>])*\?>/, x)) {
    t = x[0]			# Copy the tag verbatim
    push(replacements, t)	# Store the HTML code in replacements
    n = size(replacements)	# Get the index where it was stored
    result["html"] = "\002" n "\003"	# The tag to replace the auutolink with
    result["rest"] = substr(s, length(x[0]) + 1)
    # print "Found HTML tag <" n "> = " t > "/dev/stderr"
    return 1
  }
  return 0
}


function inline_link_or_image(s, no_links, result, replacements,
			      x, t, u, n, i, is_image)
{
  # print "trying inline_link_or_image(\"" s "\", " no_links ",...)" > "/dev/stderr"
  if (s ~ /^!\[/) { is_image = 1; s = substr(s, 3) }
  else if (s ~ /^\[/) { is_image = 0; s = substr(s, 2) }
  else return 0

  # Collect in t all the text between the initial "[" and the matching
  # "]" (the anchor text), while allowing matching bracket pairs to
  # occur between the two. Set s to the string starting with the
  # matching "]".
  t = ""
  n = 0
  while ((i = match(s, /[][]/, x))) {
    if (x[0] == "[") {
      n++
      t = t substr(s, 1, i)
      s = substr(s, i + 1)
    } else if (n != 0) {
      n--
      t = t substr(s, 1, i)
      s = substr(s, i + 1)
    } else {
      t = t substr(s, 1, i - 1)
      s = substr(s, i)
      break
    }
  }
  # print "anchor = \"" t "\"" > "/dev/stderr"

  # If s does not start with "](...)", this is not a link.
  if (! match(s, /^\]\(\s*(<([^>]*)>|([^\)[:space:]]*))(\s+"([^"]*)"|\s+'([^']*)'|\s+\(([^\)]*)\))?\s*\)(.*)/, x))
    #                     1 2     2  3               314    5     5      6     6       7      7  4      8  8
    return 0

  # print "Found URL: \"" x[2] x[3] "\"" > "/dev/stderr"

  # Convert the anchor text t to HTML. The 1 indicates that no links
  # are allowed in that text.
  t = inline(t, 1, replacements)

  # Create the HTML code for the link or image.
  if (is_image) {
    u = "<img src=\"" esc_html(esc_url(x[2] x[3])) "\"" \
      " alt=\"" esc_html(to_text(t)) "\""
    if (x[4]) u = u " title=\"" esc_html(unesc_md(x[5] x[6] x[7])) "\""
    u = u " />"
  } else if (no_links) {	     # Nested links not allowed, use text only
    u = t
  } else {
    u = "<a href=\"" esc_html(esc_url(x[2] x[3])) "\""
    if (x[4]) u = u " title=\"" esc_html(unesc_md(x[5] x[6] x[7])) "\""
    u = u ">" t "</a>"
  }

  # Store the HTML code in replacements at index n and return a tag
  # "<n>".
  push(replacements, u)
  result["html"] = "\002" size(replacements) "\003"
  result["rest"] = x[8]
  return 1
}


function inline_emphasis(s, no_links, result, replacements,	x, y, z, t, n, i, j, result1)
{
  # print "trying inline_emphasis(\"" s "\",...)" > "/dev/stderr"
  # if (s !~ /^[_*]/) return 0
  assert(s ~ /^[_*]/, "s ~ /^[_*]/")

  match(s, /^(_+|\*+)/)
  t = substr(s, 1, RLENGTH)
  result["rest"] = substr(s, RLENGTH + 1)

  while (match(s, /^((_)+|(\*)+)(.*)/, x) &&
	 (i = match(x[4], "([^[:space:][:punct:]])(" x[2] x[3] "+)(.*)|([[:punct:]])(" x[2] x[3] "+)([[:punct:][:space:]].*|$)", y))) {

    # Check if there is a left-flanking delimiter of the same type
    # ("_" or "*") before i. If so, process that one first.
    j = match(x[4], "(^|[^\\\\])(" x[2] x[3] "+)([^[:space:][:punct:]].*)|(^|[[:space:][:punct:]])(" x[2] x[3] "+)([[:punct:]].*)", z)
    # print "i=" i " j=" j " x[4]=\"" x[4] "\"" > "/dev/stderr"
    if (j != 0 && j < i &&
	inline_emphasis(z[2] z[3]  z[5] z[6], no_links, result1, replacements)) {
      t = x[1] substr(x[4], 1, j - 1) z[1] z[4] result1["html"]
      result["rest"] = result1["rest"]
      s = result["html"] result["rest"]
    } else {
      # print "found " x[1] " matched by " y[2] y[5] > "/dev/stderr"
      n = length(y[2] y[5])
      if (n > length(x[1])) n = length(x[1])
      t = inline(substr(x[4], 1, i), no_links, replacements)
      if (n > 1) {
	push(replacements, "<strong>")
	t = "\002" size(replacements) "\003" t
	push(replacements, "</strong>")
	t = t "\002" size(replacements) "\003"
      }
      if (n % 2 == 1) {
	push(replacements, "<em>")
	t = "\002" size(replacements) "\003" t
	push(replacements, "</em>")
	t = t "\002" size(replacements) "\003"
      }
      t = substr(s, 1, length(x[1]) - n) t
      result["rest"] = substr(y[2] y[5], 1, length(y[2] y[5]) - n) y[3] y[6]
      s = result["html"] result["rest"]
    }
  }
  push(replacements, t)
  result["html"] = "\002" size(replacements) "\003"
  # print "emphasized result = \"" t "\"" > "/dev/stderr"
  # print "rest = \"" result["rest"] "\"" > "/dev/stderr"
  return 1
}


function inline_strikethrough(s, no_links, result, replacements,	x, y, t, i)
{
  assert(s !~ /^~/, "s !~ /^~/")
  # print "trying inline_strikethrough(\"" s "\", " no_links ",...)" > "/dev/stderr"

  if ((match(s, /^~~(.*)/, x) &&
       (i = match(x[1], /[^~\\](~~)([^~].*|$)/, y))) ||
      (match(s, /^~([^~].*)/, x) &&
       (i = match(x[1], /[^~\\](~)([^~].*|$)/, y)))) {
    push(replacements, "<s>")
    t = "\002" size(replacements) "\003"
    t = t inline(substr(x[1], 1, i), no_links, replacements)
    push(replacements, "</s>")
    t = t "\002" size(replacements) "\003"
    result["html"] = t
    result["rest"] = y[2]
    return 1
  }
  return 0
}


# to_text -- remove markdown
function to_text(s,	t)
{
  # First convert the markdown to HTML and then remove all HTML tags,
  # replace HTML entities and remove the final newline. (Internal
  # newlines remain.) The function to_html() already replaced all
  # character entities other than "&lt;", "&gt;", "&quot;" and
  # "&amp;".
  #
  t = to_html(s)

  # Remove comments.
  gsub(/^<!--([^->]|-[^->])*-->/, "", t)

  # Replace images by their alt text.
  t = awk::gensub(/<img\>[^>]*\<alt="([^"]*)"[^>]*>/, "\\1", "g", t)
  t = awk::gensub(/<img\>[^>]*\<alt='([^']*)'[^>]*>/, "\\1", "g", t)

  # Remove all other tags.
  gsub(/<[^>]*>/, "", t)

  # Replace remaining entities.
  gsub(/&quot;/, "\"", t)
  gsub(/&gt;/, ">", t)
  gsub(/&lt;/, "<", t)
  gsub(/&amp;/, "\\&", t)

  # Remove final newline.
  gsub(/\n$/, "", t)
  # print "to_text(\"" s "\") -> \"" t "\"" > "/dev/stderr"
  return t
}


# expand_tabs - replace tabs by the right number of spaces
function expand_tabs(line,	result, col, c)
{
  # This is wrong, tabs are not supposed to be replaced by spaces,
  # except at the start of a line.

  result = ""
  col = 1
  while (line != "") {
    c = substr(line, 1, 1)
    line = substr(line, 2)
    if (c == "\t") {
      do { result = result " "; col++ } while (col % 4 != 1)
    } else {
      result = result c
      col++
    }
  }
  return result
}


# add_line_to_tree -- close and create blocks >= level and add the line
function add_line_to_tree(stack, level, line, curblock, result,
			  curtype, h, a, f)
{
  # A recursive function that checks the line against each block in
  # the stack of open blocks, starting from the outermost block (the
  # bottom of the stack). At each level in the stack, it checks what
  # to do: add the line to this block, close the block (and its
  # children) and possibly create a new block in its stead, or pass
  # the line on to be compared to the next level, after possibly
  # removing a prefix.
  #
  # E.g., if the current level is a blockquote and the line starts
  # with a ">", remove that and let the nested blocks determine what
  # to do with the rest of the line.

  # printf "add_line_to_tree(..., %d, \"%s\",...)\n",
  #   level, line > "/dev/stderr"

  h = type_of_line(line, a)

  if (level > size(stack)) {
    # At the top of the stack. Add a new block and put the line in it
    # (unless it is a blank line, which adds no block).
    #
    # printf " at top\n" > "/dev/stderr"
    assert(empty(curblock), "empty(curblock)")
    if (h == "blank-line") {
      # Nothing to do
    } else if (h == "indented-code") {
      open_block(stack, result, h, "<pre><code>")
      push(curblock, a["content"])
    } else if (h == "blockquote") {
      open_block(stack, result, h, "<blockquote>\n")
      open_block(stack, result, "placeholder", "")
      add_line_to_tree(stack, level + 1, a["content"], curblock, result)
    } else if (h == "thematic-break") {
      open_block(stack, result, h, "<hr />\n")
    } else if (h == "heading") {
      open_block(stack, result, h " " a["level"], "<h" a["level"] ">")
      push(curblock, a["content"])
    } else if (h == "list") {
      open_block(stack, result, h " " a["indent"] " " a["type"] " " a["start"],
	a["type"] ~ /[*+-]/ ? "<ul>\n" :
		 a["start"] ~ /^0*1$/ ? "<ol>\n" :
		 "<ol start=\"" a["start"] "\">\n")
      open_block(stack, result,
	"item " a["indent"] " " a["type"] " " a["start"], "<li>")
      open_block(stack, result, "placeholder", "")
      add_line_to_tree(stack, level + 2, a["content"], curblock, result)
    } else if (h == "paragraph") {
      open_block(stack, result, h, "<p>")
      add_line_to_tree(stack, level, a["content"], curblock, result)
    } else if (h == "fenced-code") {
      open_block(stack, result, h " " a["indent"] " " a["type"],
	"<pre><code" (a["class"] ? " class=\"" a["class"] "\"" : "") ">")
    } else {
      assert(0, "Unhandled line type " h " in add_line_to_tree")
    }

  } else {
    # Compare the line against the block at this level. Depending on
    # the type of the current block and its parameters (such as its
    # indent level or list marker style), and depending on the type of
    # the line, determine what to do.
    #
    split(item(stack, level), curtype)
    # printf " in %s\n", item(stack, level) > "/dev/stderr"
    switch (curtype[1]) {
    case "placeholder":		# Newly added blockquote or item
      close_blocks(stack, level, curblock, result)
      add_line_to_tree(stack, level, line, curblock, result)
      break
    case "paragraph":
      if (h == "indented-code" || h == "paragraph") {
	# The line can be added to the current block as text. Remove
	# leading spaces.
	push(curblock, awk::gensub(/^\s+/, "", 1, line))
      } else {
	# The line indicates the start of a new block. Close the
	# paragraph and call self recursively to add that new block to
	# the stack.
	close_blocks(stack, level, curblock, result)
	add_line_to_tree(stack, level, line, curblock, result)
      }
      break
    case "indented-code":
      if (h == "indented-code" || h == "blank-line") {
	# The line can be added to the current block as text.
	push(curblock, a["content"])
      } else {
	# The line indicates the start of a new block. Close the
	# indented-code block and call self recursively to add a new
	# block to the stack.
	close_blocks(stack, level, curblock, result)
	add_line_to_tree(stack, level, line, curblock, result)
      }
      break
    case "heading":
      # A heading block is always one line, so this new line closes
      # the heading block. Recursively call self to create a new block
      # for this line.
      close_blocks(stack, level, curblock, result)
      add_line_to_tree(stack, level, line, curblock, result)
      break;
    case "blockquote":
      if (h == "blockquote") {
	# The line starts with ">", so it is a continuation of the
	# current blockquote. Remove the ">" and pass on the remainder
	# to the next level.
	add_line_to_tree(stack, level + 1, a["content"], curblock, result)

      } else if ((h == "indented-code" || h == "paragraph") &&
		 top(stack) == "paragraph") {
	# The line does not start with ">", but there is currently a
	# paragraph open and the line is a valid paragraph line, so
	# treat the line as a "lazy continuation line" and pass it on
	# unmodified, to be handled by that paragraph.
	add_line_to_tree(stack, size(stack), line, curblock, result)
      } else {
	# The line does not start with ">" and is not a lazy
	# continuation, so it means the end of the blockquote. Close
	# the blockquote and call self recursively to make a new
	# block.
	close_blocks(stack, level, curblock, result)
	add_line_to_tree(stack, level, line, curblock, result)
      }
      break
    case "list":
      # Use the indent of the most recent item, rather than of the
      # first. The following should set curtype[1] to "item" and
      # curtype[2] to the indent of the item.
      split(item(stack, level + 1), curtype)
      if (h == "blank-line") {
	# A blank line does not end a list, but it may end one of its
	# descendants. Pass it on.
	add_line_to_tree(stack, level + 1, a["content"], curblock, result)
      } else if (indent_size(line) >= curtype[2]) {
	# The line is indented at least to the same level as the
	# current item of this list, which means it does not end this
	# item. Reduce the indent of the line and pass it on to be
	# handled by the current list item and its children.
	# print "line = \"" line "\"" > "/dev/stderr"
	# print "  indent = " indent_size(line) > "/dev/stderr"
	# print "  stack = \"" item(stack, level + 1) "\"" > "/dev/stderr"
	# print "  curtype[2] = " curtype[2] > "/dev/stderr"
	add_line_to_tree(stack, level + 1, unindent_line(line, curtype[2]),
			 curblock, result)
      } else if (h == "list" && a["type"] == curtype[3]) {
	# The line is a list item of the same type as the current
	# list. Close the current item and open a new one.
	close_blocks(stack, level + 1, curblock, result)
	open_block(stack, result,
	  "item " a["indent"] " " a["type"] " " a["start"], "<li>")
	open_block(stack, result, "placeholder", "")
	add_line_to_tree(stack, level + 2, a["content"], curblock, result)
      } else if ((h == "paragraph" || h == "indented-code") &&
		 top(stack) == "paragraph") {
	# There is currently a paragraph open and the line is
	# compatible with being a lazy continuation line. Pass it on
	# to that paragraph.
	add_line_to_tree(stack, size(stack), line, curblock, result)
      } else {
	# The line is of any other kind, so close the current list and
	# call self recursively to create a new block for this line.
	close_blocks(stack, level, curblock, result)
	add_line_to_tree(stack, level, line, curblock, result)
      }
      break
    case "item":
      # All the logic is in "list". This just passes the line on to
      # the next level.
      add_line_to_tree(stack, level + 1, line, curblock, result)
      break
    case "fenced-code":
      if (h == "fenced-code" && a["type"] ~ curtype[3] && a["info"] == "")
	# The line is a fenced code marker (``` or ~~~) of the same
	# type and at least as long as the marker that started the
	# fenced code block. And it does not have an info string. So
	# this is the end of the block.
	close_blocks(stack, level, curblock, result)
      else
	# Any other line is added verbatim to this block, except that
	# its indent is reduced by the indent of the code fence that
	# started the block.
	push(curblock, unindent_line(line, curtype[2]))
      break
    case "thematic-break":
      # A thematic break is always one line, so this new line closes
      # the thematic break. Then recursively call self to create a
      # block for this new line.
      close_blocks(stack, level, curblock, result)
      add_line_to_tree(stack, level, line, curblock, result)
      break
    default:
      assert(0, "Unhandled block type " curtype[1] " in add_line_to_tree")
    }
  }
}


# type_of_line -- determine the type of line and return its parts
function type_of_line(line, parts,	a, h)
{
  # The parts array is filled with noteworthy parts of the line:
  #
  # "content": The content of the line after any markers. (blank-line,
  #   indented-code, blockquote, list, heading, paragraph)
  #
  # "type": The marker. (fenced-code, list)
  #
  # "info": The info string. (fenced-code) Not currently used by any
  #   other function.
  #
  # "class": A text of the form "language-xxx", where xxx is the first
  #   word of "info", or the empty string if there is no info. (A
  #   "word" is what comes before the first space, or the whole info,
  #   if it contains no space.) (fenced-code)
  #
  # "indent": A number >= 0 indicating in which column the "content"
  #   part starts, after expanding tabs, where tabs stops are assumed
  #   every 4 characters. (list, fenced-code)
  #
  # "start": A string with a decimal number indicating the number of
  #   the first item in an ordered list. Only defined if "type" ==
  #   "1". (list)
  #
  # "level": A number between 1 and 6 indicating the heading
  #   level. (heading)
  #
  # Note that unused array items are not cleared. The caller (the
  # add_line_to_tree() function) should only inspect array items that
  # are defined for the type of line.

  if (match(line, /^\s*$/)) {
    parts["content"] = unindent_line(line, 4)
    return "blank-line"
  } else if (indent_size(line) >= 4) {
    parts["content"] = unindent_line(line, 4)
    return "indented-code"
  } else if (match(line, /^\s*((```+)([^`]*)|(~~~+)(.*))$/, a)) {
    parts["type"] = a[2] a[4]
    parts["info"] = awk::gensub(/^\s+/,"",1,awk::gensub(/\s+$/, "",1,a[3] a[5]))
    parts["class"] = parts["info"] ?
      "language-" awk::gensub(/\s.*/, "", 1, parts["info"]) : ""
    parts["indent"] = indent_size(line)
    return "fenced-code"
  } else if (match(line, /^\s*>\s?(.*)/, a)) {
    parts["content"] = a[1]
    return "blockquote"
  } else if (match(line, /^\s*((\*\s*){3,}|(-\s*){3,}|(_\s*){3,})$/)) {
    return "thematic-break"
  } else if (match(line, /^(\s*)([*+-])(\s(.*[^[:space:]].*))?$/, a)) {
    parts["content"] = 4 in a ? a[4] : ""
    parts["type"] = a[2]
    if (indent_size(parts["content"]) >= 4) # Starts with indented code block
      parts["indent"] = indent_size(a[1]) + 2
    else
      parts["indent"] = indent_size(a[1] " " a[3])
    return "list"
  } else if (match(line, /^(\s*)([0-9]{1,9})[.\)](\s(.*[^[:space:]].*))?$/, a)) {
    parts["content"] = 4 in a ? a[4] : ""
    parts["start"] = a[2]
    parts["type"] = "1"
    h = awk::gensub(/./, " ", "g", a[2])
    if (indent_size(parts["content"]) >= 4) # Starts with indented code block
      parts["indent"] = indent_size(a[1] h " ") + 1
    else
      parts["indent"] = indent_size(a[1] h " " a[3])
    return "list"
  } else if (match(line, /^\s*(#{1,6})(\s+(.*))?$/, a)) {
    parts["content"] = 3 in a ? a[3] : ""
    parts["level"] = length(a[1])
    sub(/(^|\s)+#+\s*$/, "", parts["content"]) # Remove any #'s at the end
    return "heading"
  } else if (match(line, /^\s*(.*)$/, a)) {
    parts["content"] = a[1]
    return "paragraph"
  }
  assert(!"Cannot happen", "Cannot happen")
}


# indent_size -- how much a line is indented, assuming tab stops at 4 spaces
function indent_size(line,	chars, i, n, r)
{
  n = split(line, chars, //)
  r = 0
  for (i = 1; i <= n; i++)
    if (chars[i] == " ") r++
    else if (chars[i] == "\t") r += 4 - (r + 4) % 4
    else return r
  return r
}


# unindent_line -- remove up to n spaces, assuming tab stops at 4 spaces
function unindent_line(line, n,		i)
{
  i = 0
  while (i < n) {
    if (line ~ /^\t/) {i += 4 - (i + 4) % 4; line = substr(line, 2)}
    else if (line ~ /^ /) {i++; line = substr(line, 2)}
    else i = n			# No more spaces or tabs to remove
  }
  # If the last tab removed too much, add spaces in front.
  while (i > n) {line = " " line; i--}
  return line
}


# open_block -- add a block to the stack and its start tag to the result queue
function open_block(stack, result, type, tag)
{
  # printf "open_block(..., \"%s\", %s)\n", type,
  #   awk::gensub(/\n/, " ", "g", tag) > "/dev/stderr"
  push(stack, type)
  push(result, tag)
}


# close_blocks -- serialize a block and its children into result and remove them
function close_blocks(stack, level, curblock, result,	curtype, h)
{
  # A recursive function that serializes the block at the given level,
  # and all blocks contained within it, to HTML. It adds the HTML to
  # the array "result" (which is a queue of HTML fragments). The start
  # tags of all blocks are already in the array. Only the contents of
  # the final block (which is in the curblock parameter) and the end
  # tags of all block have to be added. The blocks are then closed,
  # i.e., removed from the stack.
  #
  # Depending on the kind of block at the top (paragraph, heading,
  # indented code or fenced code), the contents are parsed as inline
  # markdown or copied as-is.
  #
  # "curblock" is an array (queue) of lines without newlines.

  if (level <= size(stack)) {
    split(item(stack, level), curtype)
    # printf "close_blocks(..., %d, \"%s\",...)\n",
    #   level, item(stack, level) > "/dev/stderr"
    switch (curtype[1]) {
    case "placeholder":		# Newly opened blockquote or item
      break;
    case "paragraph":
      push(result, awk::gensub(/ +$/, "", 1,
	to_inline_html(join(curblock, "\n"))))
      destroy(curblock)
      push(result, "</p>\n")
      break
    case "blockquote":
      close_blocks(stack, level + 1, curblock, result)
      push(result, "</blockquote>\n")
      break
    case "heading":
      push(result, awk::gensub(/ +$/, "", 1,
	to_inline_html(join(curblock, "\n"))))
      destroy(curblock)
      push(result, "</h" curtype[2] ">\n")
      break
    case "list":
      close_blocks(stack, level + 1, curblock, result)
      push(result, curtype[3] ~ /[*+-]/ ? "</ul>\n" : "</ol>\n")
      break
    case "item":
      close_blocks(stack, level + 1, curblock, result)
      push(result, "</li>\n")
      break
    case "indented-code":
      h = join(curblock, "\n")
      sub(/\n+$/, "", h)	# Empty lines before the end are removed
      if (h != "") push(result, esc_html(h) "\n")
      destroy(curblock)
      push(result, "</code></pre>\n")
      break
    case "thematic-break":
      break
    case "fenced-code":
      h = join(curblock, "\n")
      if (h != "") push(result, esc_html(h) "\n")
      destroy(curblock)
      push(result, "</code></pre>\n")
      break
    default:
      assert(0, "Unhandled block type: " curtype[1] " in close_blocks()")
    }

    pop(stack)
  }
}


# unesc_md -- unescape backslashed punctuation & character entities in markdown
function unesc_md(s,	t, a, h)
{
  # Loop over s looking for backslash + punctuation or HTML character
  # entities. Unknown entity references are copied as is. Backslashes
  # not followed by punctuation are copied as-is, Ampersands not
  # followed by an entity name or number are also copied as-is.
  #
  t = ""
  while (match(s, /\\([!"#$%&'()*+,./:;<=>?@[\\\]^_`{|}~}-])|&([a-zA-Z][a-zA-Z0-9.-]*|#(x[0-9a-fA-F]+|[0-9]+));/, a)) {
    if (a[0] ~ /^\\/) h = a[1]
    else if (a[2] ~ /^#x/) h = sprintf("%c", strtonum("0" a[3]))
    else if (a[2] ~ /^#/) h = sprintf("%c", a[3])
    else if (a[2] in htmlmathml::ent) h = htmlmathml::ent[a[2]]
    else h = a[0]		# Unknown named entity, leave as-is
    t = t substr(s, 1, RSTART - 1) h
    s = substr(s, RSTART + RLENGTH)
  }

  return t s
}


# esc_html -- escape HTML delimiters
function esc_html(s)
{
  gsub(/&/, "\\&amp;", s)
  gsub(/</, "\\&lt;", s)
  gsub(/>/, "\\&gt;", s)
  gsub(/"/, "\\&quot;", s)
  return s
}


# esc_url -- %-escape certain characters for use in a URL
function esc_url(s)
{
  gsub(/\\/, "%5C", s)
  gsub(/\[/, "%5B", s)		# Not necessary, but matches the spec examples
  gsub(/\]/, "%5D", s)		# Not necessary, but matches the spec examples
  return s
}


# Functions to handle queues and stacks.
#
# A queue or stack is automatically initialized the first time a value
# is added.
#
# Calling pop(), top(), unshift() or first() on an empty queue or
# stack returns an unassigned value, i.e., typeof() on that value
# yields "unassigned".
#
# Queues and stacks are implemented as arrays. The values are stored
# at consecutive numeric indices in the array: x[n], x[n+1], x[n+2],
# etc. The special entries x["first"] and x["last"] contain the
# indices of the first and last values in the queue/stack. If
# x["last"] < x["first"], or if x is uninitialized, it means the
# queue/stack is empty.


# push -- add a value to a stack or a queue, return the value
function push(stack, value)
{
  # If stack is uninitialized, initialize it
  if (awk::typeof(stack) == "untyped") {
    stack["first"] = 1
    stack["last"] = 0
  }
  stack[++stack["last"]] = value
  return value
}


# pop -- return the top value on the stack and remove it from the stack
function pop(stack,	v)
{
  if (! empty(stack)) {
    v = stack[stack["last"]]
    delete stack[stack["last"]]
    stack["last"]--
  }
  return v
}


# top -- return the top value of a stack
function top(stack)
{
  return stack[stack["last"]]
}


# shift -- add an item at the start of a queue, return the item
function shift(queue, value)
{
  # If the queue is uninitialized, initialize it
  if (awk::typeof(queue) == "untyped") {
    queue["first"] = 1
    queue["last"] = 0
  }
  queue[--queue["first"]] = value
  return value
}


# unshift -- return the first item in a queue and remove it from the queue
function unshift(queue,		v)
{
  if (! empty(queue)) {
    v = queue[queue["first"]]
    delete queue[queue["first"]]
    queue["first"]++
  }
  return v
}

# first -- return the first item in a queue
function first(queue)
{
  return stack[stack["first"]]
}


# item -- get the n'th value of a queue or stack
function item(queue, n)
{
  return queue[queue["first"] + n - 1]
}


# destroy -- make a stack or queue empty
function destroy(queue)
{
  while (! empty(queue)) pop(queue)
}


# join -- join a stack or queue of strings into a single string with separators
function join(queue, sep,	result, i)
{
  if (empty(queue)) return ""
  i = queue["first"]
  result = queue[i]
  while (++i <= queue["last"]) result = result sep queue[i]
  return result
}


# size -- number of values in a queue or stack
function size(queue)
{
  if (awk::typeof(queue) != "array") return 0
  else return queue["last"] + 1 - queue["first"]
}


# empty -- check if a stack or a queue is empty
function empty(stack)
{
  if (awk::typeof(stack) != "array") return 1
  else return stack["last"] < stack["first"]
}


# assert -- assert that a condition is true, otherwise exit
function assert(condition, string)
{
  if (! condition) {
    printf "%s:%d: assertion failed: %s\n",
      FILENAME, FNR, string > "/dev/stderr"
    awk::_assert_exit = 1
    exit 1
  }
}


