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
    add_line_to_tree(stack, 1, lines[i], curblock, result)
  }
  close_blocks(stack, 1, curblock, result)
  return join(result)
}


# to_inline_html -- convert markdown to inline HTML
function to_inline_html(s,	rstart, rstart1, z, y, x, h)
{
  if ((rstart1 = match(s, /(^|[^\\])?((<\/?[a-zA-Z0-9_-]+|!?\[|[`~_*])(.*))/, z))) {
    #                             1         23                               4
    # z[1] = last char before delimiter, or undefined if none
    # z[2] = the part of s that starts with the delimiter
    # z[3] = the delimiter
    # z[4] = the part of s after the delimiter
    # Treat HTML tags, autolinks, images, hyperlinks, inline code,
    # strikethrough and emphasis from left to right.
    # printf " Possible delim: \"%s\"\n", z[3] > "/dev/stderr"

    if (match(z[2], /^<([a-zA-Z]+:[^>[:space:]]+)>(.*)/, x)) {
      # Autolink (URL): <scheme:...>
      return to_inline_html(substr(s, 1, rstart1 - 1) z[1])	\
	"<a href=\"" esc_html(x[1]) "\">" esc_html(x[1]) "</a>"			\
	to_inline_html(x[3])

    } else if (match(z[2], /^(<\/?([a-zA-Z][a-zA-Z0-9_-]*)(\s[^>]*)?>)(.*)/, x) &&
	       x[2] !~ /^(title|textarea|style|xmp|iframe|noembed|noframes|script|plaintext)$/) {
      # Looks like an allowed HTML tag. Copy unchanged.
      return to_inline_html(substr(s, 1, rstart1 - 1) z[1])	\
	x[1] to_inline_html(x[4])

    } else if (match(z[2], /^(`+)(.*)/, x) &&
	       (rstart = match(x[2], "[^\\\\]" x[1] "(.*)", y))) {
      # Inline code: `...` or ``...`` or etc.
      h = substr(x[2], 1, rstart) # Include the char before closing delim
      if (h ~ /^[ \t].*[ \t]$/) h = substr(h, 2, length(h) - 2)
      return to_inline_html(substr(s, 1, rstart1 - 1) z[1])	\
	"<code>" esc_html(h) "</code>" to_inline_html(y[1])

    } else if (match(z[2], /^!\[(([^\]]|\\\])+)\]\(\s*(<([^>]*)>|([^\)[:space:]]*))([ \t]+("([^"]*)"|'([^']*)'|\(([^\)]*)\)))?\s*\)(.*)/, x)) {
      #                         12                    3 4        5                 6      7 8         9          10                11
      # x[1] = alt text, x[4] or x[5] = URL, x[8] or x[9] or x[10] = title
      # Image: ![alt text](url) or  ![alt text](url "title")
      return to_inline_html(substr(s, 1, rstart1 - 1) z[1])	\
	"<img src=\"" esc_html(markdown::to_text(x[4] x[5])) "\" alt=\"" \
	esc_html(markdown::to_text(x[1])) "\""				\
	(x[6] ? " title=\"" esc_html(markdown::to_text(x[8] x[9] x[10])) "\"" :
	 "") ">" to_inline_html(x[11])

    } else if (match(z[2], /^\[(([^\]]|\\\])+)\]\(\s*(<([^>]*)>|([^\)[:space:]]*))([ \t]+("([^"]*)"|'([^']*)'|\(([^\)]*)\)))?\s*\)(.*)/, x)) {
      #                        12                    3 4        5                 6      7 8         9          10                11
      # Hyperlinks: [anchor](url) or [anchor](url "title")
      # x[1] = anchor, x[4] or x[5] = URL, x[8] or x[9] or x[10] = title
      return to_inline_html(substr(s, 1, rstart1 - 1) z[1])	\
	"<a href=\"" esc_html(markdown::to_text(x[4] x[5])) "\""	\
	(x[6] ? " title=\"" esc_html(markdown::to_text(x[8] x[9] x[10])) "\"" :
	 "") ">" to_inline_html(x[1]) "</a>"	\
	to_inline_html(x[11])

    } else if (z[1] != "~" &&
	       match(z[2], /^(~~?)([^~].*)/, x) &&
	       (rstart = match(x[2], "[^~\\\\]" x[1] "([^~].*|$)", y))) {
      # Strikethrough: ~...~ or ~~...~~
      return to_inline_html(substr(s, 1, rstart1 - 1) z[1])	\
	"<del>" to_inline_html(substr(x[2], 1, rstart)) "</del>" \
	to_inline_html(y[1])

    } else if (z[1] ~ /^[^[:alnum:]]?$/ &&
	       (match(z[2], /^___([^[:space:]].*)/, x) &&
		(rstart = match(x[1], /[^[:space:][:punct:]]___([^[:alnum:]].*|$)|[^[:space:]\\]___([[:space:][:punct:]].*|$)/, y))) ||
	       (match(z[2], /^\*\*\*([^[:space:]].*)/, x) &&
		(rstart = match(x[1], /[^[:space:][:punct:]]\*\*\*([^[:alnum:]].*|$)|[^[:space:]\\]\*\*\*([[:space:][:punct:]].*|$)/, y)))) {
      # Bold + italic: ***...*** or ___...___
      return to_inline_html(substr(s, 1, rstart1 - 1) z[1])	\
	"<strong><em>" to_inline_html(substr(x[1], 1, rstart)) "</em></strong>" \
	to_inline_html(y[1] y[2])

    } else if (z[1] ~ /^[^[:alnum:]]?$/ &&
	       (match(z[2], /^__([^[:space:]].*)/, x) &&
		(rstart = match(x[1], /[^[:space:][:punct:]]__([^[:alnum:]].*|$)|[^[:space:]\\]__([[:space:][:punct:]].*|$)/, y))) ||
	       (match(z[2], /^\*\*([^[:space:]].*)/, x) &&
		(rstart = match(x[1], /[^[:space:][:punct:]]\*\*([^[:alnum:]].*|$)|[^[:space:]\\]\*\*([[:space:][:punct:]].*|$)/, y)))) {
      # Bold : **...** or __...__
      return to_inline_html(substr(s, 1, rstart1 - 1) z[1])	\
	"<strong>" to_inline_html(substr(x[1], 1, rstart)) "</strong>"	\
	to_inline_html(y[1] y[2])

    } else if (z[1] ~ /^[^[:alnum:]]?$/ &&
	       (match(z[2], /^_([^[:space:]].*)/, x) &&
		(rstart = match(x[1], /[^[:space:][:punct:]]_([^[:alnum:]].*|$)|[^[:space:]\\]_([[:space:][:punct:]].*|$)/, y))) ||
	       (match(z[2], /^\*([^[:space:]].*)/, x) &&
		(rstart = match(x[1], /[^[:space:][:punct:]]\*([^[:alnum:]].*|$)|[^[:space:]\\]\*([[:space:][:punct:]].*|$)/, y)))) {
      # Bold : *...* or _..._
      return to_inline_html(substr(s, 1, rstart1 - 1) z[1])	\
	"<em>" to_inline_html(substr(x[1], 1, rstart)) "</em>"		\
	to_inline_html(y[1] y[2])

    } else {
      # Unmatched delimiter, treat as text.
      # printf " ... unmatched\n", z[3] > "/dev/stderr"
      return esc_html(unesc_md(substr(s, 1, rstart1 - 1) z[1] z[3])) \
	to_inline_html(z[4])
    }

  } else {
    # printf " \"%s\"\n", s > "/dev/stderr"
    # Remove escapes. Backslash + newline and two or more spaces +
    # newline turn into <br>.
    # TODO: This also turns "&bsol;" + newline into "<br>". Is that right?
    return awk::gensub(/(\\|  +)\n/, "<br>\n", "g", esc_html(unesc_md(s)))
  }
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
  gsub(/<[^>]*>/, "", t)
  gsub(/&quot;/, "\"", t)
  gsub(/&gt;/, ">", t)
  gsub(/&lt;/, "<", t)
  gsub(/&amp;/, "\\&", t)
  gsub(/\n$/, "", t)
  return t
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
      open_block(stack, result, h, "<hr>\n")
    } else if (h == "heading") {
      open_block(stack, result, h " " a["level"], "<h" a["level"] ">")
      push(curblock, a["content"])
    } else if (h == "list") {
      open_block(stack, result, h " " a["indent"] " " a["type"] " " a["start"],
	a["type"] ~ /[*+-]/ ? "<ul>\n" :
		 a["start"] ~ /^0*1$/ ? "<ol>\n" :
		 "<ol start=\"" a["start"] "\">\n")
      open_block(stack, result, "item", "<li>")
      open_block(stack, result, "placeholder", "")
      add_line_to_tree(stack, level + 2, a["content"], curblock, result)
    } else if (h == "paragraph") {
      open_block(stack, result, h, "<p>")
      add_line_to_tree(stack, level, a["content"], curblock, result)
    } else if (h == "fenced-code") {
      open_block(stack, result, h " " a["type"],
	"<pre" (a["class"] ? " class=\"" a["class"] "\"" : "") "><code>")
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
	push(curblock, awk::gensub(/^\s*/, "", 1, line))
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
      if (h == "blank-line") {
	# A blank line does not end a list, but it may end one of its
	# descendants. Pass it on.
	add_line_to_tree(stack, level + 1, a["content"], curblock, result)
      } else if (indent_size(line) >= curtype[2]) {
	# The line is indented at least to the same level as the first
	# line of the first item of this list, which means it does not
	# end this list. Reduce the indent of the line and pass it on
	# to be handled by the current list item and its children.
	add_line_to_tree(stack, level + 1, unindent_line(line, curtype[2]),
			 curblock, result)
      } else {
	# The indent of the is not enough to be sure that it is part
	# of the current list item of this list. Remove whatever
	# indentation it has and see what kind of line it is.
	f = unindent_line(line, curtype[2])
	h = type_of_line(f, a)
	if (h == "list" && a["type"] == curtype[3]) {
	  # The line indicates a list item of the same type as the
	  # current list. So close the current list item and add a new
	  # one. Then call self recursively to add the contents of the
	  # line (after the list marker) to the newly created item.
	  close_blocks(stack, level + 1, curblock, result)
	  open_block(stack, result, "item", "<li>")
	  open_block(stack, result, "placeholder", "")
	  add_line_to_tree(stack, level + 2, a["content"], curblock, result)
	} else if (h == "paragraph" && top(stack) == "paragraph") {
	  # There is currently a paragraph open and the line (without
	  # indentation) is a valid paragraph line. So the line is a
	  # lazy continuation line. Pass it on to that paragraph.
	  add_line_to_tree(stack, size(stack), f, curblock, result)
	} else {
	  # The line is of any other kind, so close the current list
	  # and call self recursively to create a new block for this
	  # line.
	  close_blocks(stack, level, curblock, result)
	  add_line_to_tree(stack, level, line, curblock, result)
	}
      }
      break
    case "item":
      # All the logic is in "list". This just passes the line on to
      # the next level.
      add_line_to_tree(stack, level + 1, line, curblock, result)
      break
    case "fenced-code":
      if (h == "fenced-code" && curtype[2] ~ "^" a["type"])
	# The line is a fenced code marker (``` or ~~~) of the same
	# type and at least as long as the marker that started the
	# fenced code block. So this is the end of the block.
	close_blocks(stack, level, curblock, result)
      else
	# Any other line is added verbatim to this block.
	push(curblock, line)
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
  #   every 4 characters. (list)
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
  } else if (match(line, /^\s*((```+)([^`]*)|(~~~+)([^~]*))$/, a)) {
    parts["type"] = a[2] a[4]
    parts["info"] = trim(a[3] a[5])
    parts["class"] = parts["info"] ?
      "language-" awk::gensub(/\s.*/, "", 1, parts["info"]) : ""
    return "fenced-code"
  } else if (match(line, /^\s*>\s?(.*)/, a)) {
    parts["content"] = a[1]
    return "blockquote"
  } else if (match(line, /^\s*([*+-])(\s(.*))?$/, a)) {
    parts["content"] = a[3]
    parts["type"] = a[1]
    parts["indent"] = indent_size(awk::gensub(/[*+-]/, " ", 1, line))
    return "list"
  } else if (match(line, /^\s*([0-9]{1,9})[.\)](.*)$/, a)) {
    parts["content"] = a[2]
    parts["start"] = a[1]
    parts["type"] = "1"
    h = awk::gensub(/./, " ", "g", a[1])
    parts["indent"] = indent_size(awk::gensub(/[0-9]+[.\)]/, h " ", 1, line))
    return "list"
  } else if (match(line, /^\s*(#{1,6})(\s+(.*))?$/, a)) {
    parts["content"] = a[3]
    parts["level"] = length(a[1])
    return "heading"
  } else if (match(line, /^\s*((\*\s*){3,}|(-\s*){3,}|(_\s*){3,})$/)) {
    return "thematic-break"
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
function close_blocks(stack, level, curblock, result,	curtype)
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
      push(result, to_inline_html(join(curblock, "\n")))
      destroy(curblock)
      push(result, "</p>\n")
      break
    case "blockquote":
      close_blocks(stack, level + 1, curblock, result)
      push(result, "</blockquote>\n")
      break
    case "heading":
      push(result, to_inline_html(join(curblock, "\n")))
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
      push(result, esc_html(join(curblock, "\n")))
      destroy(curblock)
      push(result, "\n</code></pre>\n")
      break
    case "thematic-break":
      break
    case "fenced-code":
      push(result, esc_html(join(curblock, "\n")))
      destroy(curblock)
      push(result, "\n</code></pre>\n")
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


