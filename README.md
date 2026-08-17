# UrlAsMarkdown

A PowerShell 7 module that fetches a web page and converts its HTML to clean Markdown
suitable for LLM context. Scripts, styles, nav/header/footer chrome, and common
sidebar/cookie/newsletter blocks are stripped; headings, tables, lists, links,
blockquotes, and code blocks are preserved.

No external dependencies — regex and `System.Net.WebUtility` only.

## Install

Clone into any directory on your `$env:PSModulePath`, keeping the inner `UrlAsMarkdown`
folder name intact (PowerShell matches the folder name to the module name for autoloading):

```powershell
git clone git@github.com:michaelsanford/UrlAsMarkdown.psm1.git
Copy-Item .\UrlAsMarkdown.psm1\UrlAsMarkdown -Destination "$HOME\Documents\PowerShell\Modules\" -Recurse
```

Or symlink the module folder at your module path to a working clone:

```powershell
New-Item -ItemType SymbolicLink `
    -Path   "$HOME\Documents\PowerShell\Modules\UrlAsMarkdown" `
    -Target "<clone>\UrlAsMarkdown"
```

No `Import-Module` or `$PROFILE` entry is needed — the manifest declares its exported
function, so PowerShell autoloads the module the first time you call it.

## Usage

Return Markdown on the pipeline:

```powershell
Get-UrlAsMarkdown https://example.com/article
```

Save to a file (`-Save` derives the filename from the URL slug; `-OutputPath` names it):

```powershell
Get-UrlAsMarkdown https://example.com/article -Save
Get-UrlAsMarkdown https://example.com/article -OutputPath article.md -IncludeSource
```

Pipe several URLs, copy the result to the clipboard, or chain it anywhere a string works:

```powershell
$urls | Get-UrlAsMarkdown | Set-Clipboard
```

`-IncludeSource` prepends a `> Source: <url>` line. `-Verbose` reports fetch, conversion,
and save progress. Full help: `Get-Help Get-UrlAsMarkdown -Full`.

### Parameters

| Parameter | Description |
| --- | --- |
| `-Url` | The page to convert. Accepts pipeline input, by value or by property name. |
| `-OutputPath` | File to write. Implies `-Save`. |
| `-Save` | Write to a file; without `-OutputPath`, the filename comes from the URL slug. |
| `-IncludeSource` | Prepend a source-URL blockquote. |

Without `-Save` or `-OutputPath` the Markdown is returned as a string; with either, the
file is written and a `FileInfo` is returned.

## Notes

The converter is regex-based, not a DOM parser. That keeps it dependency-free and fast,
but deeply nested or malformed markup can convert imperfectly — in particular, nested
lists are flattened and tables inside tables are not handled.

## Development

```powershell
Invoke-ScriptAnalyzer -Path .\UrlAsMarkdown -Severity Error,Warning,Information
```

The module lints clean at those severities; keep it that way. Bump `ModuleVersion` in
`UrlAsMarkdown.psd1` alongside any behaviour change and tag the release to match.
