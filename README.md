# UrlAsMarkdown

[![CI](https://github.com/michaelsanford/UrlAsMarkdown.psm1/actions/workflows/ci.yml/badge.svg)](https://github.com/michaelsanford/UrlAsMarkdown.psm1/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell 7](https://img.shields.io/badge/PowerShell-7%2B-5391FE.svg)](https://github.com/PowerShell/PowerShell)

**[Documentation &amp; overview &rarr;](https://www.michaelsanford.com/UrlAsMarkdown.psm1/)**

A PowerShell 7 module that fetches a web page and converts its HTML to clean Markdown
suitable for LLM context. Scripts, styles, nav/header/footer chrome, and common
sidebar/cookie/newsletter blocks are stripped; headings, tables, lists, links,
blockquotes, and code blocks are preserved.

No external dependencies — regex and `System.Net.WebUtility` only.

## Install

PowerShell discovers modules by scanning the directories in `$env:PSModulePath` for
folders whose **name matches the module name**. So whichever method you pick, the folder
that lands on your module path must be called `UrlAsMarkdown` — the repository directory
is named `UrlAsMarkdown.psm1` (after the GitHub repo) and cannot be used directly.

Check where your personal module path points:

```powershell
$env:PSModulePath -split [IO.Path]::PathSeparator
```

On PowerShell 7 the per-user directory is `$HOME\Documents\PowerShell\Modules` (Windows)
or `~/.local/share/powershell/Modules` (Linux/macOS). Create it if it does not exist.

### Option 1 — copy the module folder (simplest)

```powershell
git clone https://github.com/michaelsanford/UrlAsMarkdown.psm1.git
Copy-Item .\UrlAsMarkdown.psm1\UrlAsMarkdown `
    -Destination "$HOME\Documents\PowerShell\Modules\" -Recurse
```

Update by re-pulling and re-copying.

### Option 2 — symlink to a working clone (best for development)

Edits in the clone take effect immediately, and `git pull` is the update path.

```powershell
New-Item -ItemType SymbolicLink `
    -Path   "$HOME\Documents\PowerShell\Modules\UrlAsMarkdown" `
    -Target "<clone>\UrlAsMarkdown"
```

Creating symlinks on Windows requires Developer Mode or an elevated prompt; use
`-ItemType Junction` instead if neither is available. Avoid placing the clone itself
inside a synced folder (OneDrive, Dropbox) — sync racing a checkout can corrupt `.git`.

### Option 3 — add the clone to `$env:PSModulePath`

Because the repository root *contains* the `UrlAsMarkdown` folder, the root itself works
as a module path entry. Nothing is copied or linked. Add to your `$PROFILE`:

```powershell
$env:PSModulePath += [IO.Path]::PathSeparator + "<clone>"
```

### Verify

```powershell
Get-Module UrlAsMarkdown -ListAvailable
Get-Command Get-UrlAsMarkdown
```

No `Import-Module` or `$PROFILE` entry is needed for options 1 and 2 — the manifest
declares its exported function, so PowerShell autoloads the module the first time you
call `Get-UrlAsMarkdown`.

### Uninstall

Delete the folder (or symlink) from your module path:

```powershell
Remove-Item "$HOME\Documents\PowerShell\Modules\UrlAsMarkdown" -Recurse -Force
```

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
Install-Module Pester, PSScriptAnalyzer -Scope CurrentUser   # once

Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error, Warning, Information
Invoke-Pester -Path .\tests
```

The repository lints clean at those severities and all tests pass; keep it that way.
Bump `ModuleVersion` in `UrlAsMarkdown.psd1` alongside any behaviour change and tag the
release to match.

### Tests

`tests/UrlAsMarkdown.Tests.ps1` covers the exported surface, each conversion rule, and
the `Get-UrlAsMarkdown` wrapper. The private helpers are exercised through
`InModuleScope`, and `Invoke-WebRequest` is mocked — **the suite never touches the
network**, so it is deterministic and safe to run offline.

### Continuous integration

`.github/workflows/ci.yml` runs on every push and pull request to `main`, across
Windows, Linux, and macOS: PSScriptAnalyzer (any finding fails the build), manifest
validation, an import-and-check-exports step, and Pester. Actions are pinned to commit
SHAs; analyzer and Pester versions are pinned in the workflow's `env` block.

`.github/workflows/publish.yml.disabled` is an inert scaffold for publishing to
PSGallery on a version tag. See the comments at the top of that file to enable it.

## License

MIT — see [LICENSE](LICENSE).
