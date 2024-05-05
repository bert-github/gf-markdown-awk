# gf-markdown-awk
Awk library to convert GitHub-flavored markdown to HTML or to plain text.

To use this to make a program that converts markdown to HTML, write the following Awk code:

    @include "markdown.awk"
    { lines = lines $0 "\n" }
    END { printf "%s", markdown::to_html(lines) }

(Requires the Gnu version of Awk, because it uses ‘@include’ and namespaces.)

More documentation is included in the `markdown.awk` file.

## What is this for?
There are several programs that convert markdown ([GitHub-flavored markdown](https://github.github.com/gfm/) or other dialects) to HTML and this one isn't the best (see [limitations](#limitations) below). So why this code?

It's not a program, but a library. (Although it only requires three lines to make it a program, see above). And in particular it is a library for *Awk.* It is meant for people who need to add markdown support to an Awk program.

You could, of course, call an external program from your Awk script to convert markdown to HTML. But this library provides two extra functions that may occasionally be handy and that existing programs don't provide. (At least I haven't found any.) And that is the ability to parse inline markdown only, i.e., bold, italics, links, etc., while ignoring paragraphs, lists, etc.; and the ability to strip markdown from text to retain just the plain text content.

The former is provided by the function `markdown::to_inline_html()`, the latter by the function `markdown::to_text()`.

## Limitations

The code does not currently implement ‘setexts headings’ (headings that are underlined instead of prefixed with one or more ‘#’ characters), ‘tight lists’ (lists where the generated HTML looks like `<li>item</li>` instead of `<li><p>item</p></li>`), tables, and CDATA sections (`<!CDATA[...]>`).

Character entities, such as `&eacute;` and `&#233;`, only expand correctly in UTF-8 locales.

The code does not currently implement extended autolinks (bare URLs, email addresses and certain domain names).

The code does not currently implement the task list extension, i.e., `[x]` is not transformed into a checkbox.

HTML blocks are not currently handled, which means, e.g., that occurrences of HTML elements `<pre>`, `<script>` and `<style>`, HTML comments, CDATA sections and processing instructions are often not handled correctly when they span multiple lines.

The tables extension is not implemented.

Link reference definitions are not supported.

## Differences from the specification

Here are the known differences from the [specification](https://github.github.com/gfm/):

### Tabs are expanded

The specification says that tabs are replaced by spaces only when they take part in determining the indentation of an input line. Tabs inside the contents of a line are passed through unchanged. This implementation expands all tabs to spaces. (But that might change in the future.)

### `> in disallowed raw HTML

When encountering disallowed tags (`<title>`, `<textarea>`, `<style>` and others), this implementation replaces their `<` and `>` by `&lt;` and `&gt;`. The specification only replaces the `<`.

### Backslash in HTML tags

The specification does not allows backslashes to occur in HTML tags, except just before a newline. The implementation doesn't allow them before a newline either.

### Whitespace between tags

This implementation outputs `<li><p>` on one line, while the examples in the specification put a newline between the tags.

## Bugs
Probably.
