function Get-CommentFreeHtml {
    param([string]$Html)
    return [regex]::Replace($Html, '<!--.*?-->', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
}

function Get-TagBlockFreeHtml {
    param([string]$Html, [string[]]$Tags)
    foreach ($tag in $Tags) {
        $Html = [regex]::Replace($Html, "<$tag\b[^>]*>.*?</$tag>", '', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    return $Html
}

function ConvertFrom-HtmlEntity {
    param([string]$Text)
    $Text = [System.Net.WebUtility]::HtmlDecode($Text)
    $Text = [regex]::Replace($Text, '&#(\d+);', { param($m) [char][int]$m.Groups[1].Value })
    return $Text
}

function Protect-AngleBracket {
    param([string]$Text)
    return $Text -replace '<', '%%LT%%' -replace '>', '%%GT%%'
}

function Get-HtmlTextContent {
    param([string]$Html)
    $text = [regex]::Replace($Html, '<[^>]+>', ' ')
    $text = Protect-AngleBracket (ConvertFrom-HtmlEntity $text)
    $text = [regex]::Replace($text, '[ \t]+', ' ')
    return $text.Trim()
}

function ConvertTo-MarkdownTable {
    param([string]$TableHtml)

    $rows = [regex]::Matches($TableHtml, '<tr\b[^>]*>(.*?)</tr>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if ($rows.Count -eq 0) { return '' }

    $mdRows = @()
    $isFirst = $true

    foreach ($row in $rows) {
        $cells = [regex]::Matches($row.Groups[1].Value, '<t[hd]\b[^>]*>(.*?)</t[hd]>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        if ($cells.Count -eq 0) { continue }

        $cellTexts = @()
        foreach ($cell in $cells) {
            $cellTexts += (Get-HtmlTextContent $cell.Groups[1].Value) -replace '\|', '\|'
        }

        $mdRows += "| $($cellTexts -join ' | ') |"

        if ($isFirst) {
            $separator = @('---') * $cellTexts.Count
            $mdRows += "| $($separator -join ' | ') |"
            $isFirst = $false
        }
    }

    return ($mdRows -join "`n")
}

function ConvertTo-MarkdownList {
    param([string]$ListHtml, [string]$ListType)

    $items = [regex]::Matches($ListHtml, '<li\b[^>]*>(.*?)</li>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $mdLines = @()
    $counter = 1

    foreach ($item in $items) {
        $text = Get-HtmlTextContent $item.Groups[1].Value
        if ([string]::IsNullOrWhiteSpace($text)) { continue }

        if ($ListType -eq 'ol') {
            $mdLines += "$counter. $text"
            $counter++
        } else {
            $mdLines += "- $text"
        }
    }

    return ($mdLines -join "`n")
}

function ConvertFrom-HtmlToMarkdown {
    param([string]$Html)

    $Html = Get-CommentFreeHtml $Html
    $Html = Get-TagBlockFreeHtml -Html $Html -Tags @('script', 'style', 'nav', 'footer', 'header', 'noscript', 'svg', 'iframe')

    $mainMatch = [regex]::Match($Html, '<(?:main|article)\b[^>]*>(.*)</(?:main|article)>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($mainMatch.Success) {
        $Html = $mainMatch.Groups[1].Value
    } else {
        $bodyMatch = [regex]::Match($Html, '<body\b[^>]*>(.*)</body>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($bodyMatch.Success) {
            $Html = $bodyMatch.Groups[1].Value
        }
    }

    $Html = [regex]::Replace($Html, '<(?:div|section|aside)\b[^>]*(?:class|id)="[^"]*(?:sidebar|cookie|popup|modal|newsletter|social-share|advertisement|ad-)[^"]*"[^>]*>.*?</(?:div|section|aside)>', '', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $Html = [regex]::Replace($Html, '<table\b[^>]*>(.*?)</table>', {
        param($m)
        "`n`n%%TABLE_START%%`n$(ConvertTo-MarkdownTable $m.Groups[1].Value)`n%%TABLE_END%%`n`n"
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $Html = [regex]::Replace($Html, '<(ol)\b[^>]*>(.*?)</ol>', {
        param($m)
        "`n`n%%LIST_START%%`n$(ConvertTo-MarkdownList $m.Groups[2].Value 'ol')`n%%LIST_END%%`n`n"
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $Html = [regex]::Replace($Html, '<(ul)\b[^>]*>(.*?)</ul>', {
        param($m)
        "`n`n%%LIST_START%%`n$(ConvertTo-MarkdownList $m.Groups[2].Value 'ul')`n%%LIST_END%%`n`n"
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $Html = [regex]::Replace($Html, '<blockquote\b[^>]*>(.*?)</blockquote>', {
        param($m)
        $text = Get-HtmlTextContent $m.Groups[1].Value
        "`n`n> $text`n`n"
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    for ($i = 6; $i -ge 1; $i--) {
        $prefix = '#' * $i
        $Html = [regex]::Replace($Html, "<h$i\b[^>]*>(.*?)</h$i>", {
            param($m)
            $text = Get-HtmlTextContent $m.Groups[1].Value
            "`n`n$prefix $text`n`n"
        }, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    $Html = [regex]::Replace($Html, '<a\b[^>]*href="([^"]*)"[^>]*>(.*?)</a>', {
        param($m)
        $href = $m.Groups[1].Value
        $text = Get-HtmlTextContent $m.Groups[2].Value
        if ([string]::IsNullOrWhiteSpace($text)) { return '' }
        if ($href -match '^#' -or $href -match '^javascript:') { return $text }
        return "[$text]($href)"
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $Html = [regex]::Replace($Html, '<(?:strong|b)\b[^>]*>(.*?)</(?:strong|b)>', {
        param($m)
        $text = Get-HtmlTextContent $m.Groups[1].Value
        "**$text**"
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $Html = [regex]::Replace($Html, '<(?:em|i)\b[^>]*>(.*?)</(?:em|i)>', {
        param($m)
        $text = Get-HtmlTextContent $m.Groups[1].Value
        "*$text*"
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $Html = [regex]::Replace($Html, '<pre\b[^>]*><code\b[^>]*>(.*?)</code></pre>', {
        param($m)
        $code = Protect-AngleBracket (ConvertFrom-HtmlEntity ($m.Groups[1].Value -replace '<[^>]+>', ''))
        "`n`n```````n$code`n```````n`n"
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $Html = [regex]::Replace($Html, '<code\b[^>]*>(.*?)</code>', {
        param($m)
        $code = Protect-AngleBracket (ConvertFrom-HtmlEntity ($m.Groups[1].Value -replace '<[^>]+>', ''))
        "``$code``"
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $Html = [regex]::Replace($Html, '<p\b[^>]*>(.*?)</p>', {
        param($m)
        $text = Get-HtmlTextContent $m.Groups[1].Value
        if ([string]::IsNullOrWhiteSpace($text)) { return '' }
        "`n`n$text`n`n"
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $Html = [regex]::Replace($Html, '<br\s*/?>', "`n", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $Html = [regex]::Replace($Html, '<hr\s*/?>', "`n`n---`n`n", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $Html = [regex]::Replace($Html, '<[^>]+>', '')
    $Html = ConvertFrom-HtmlEntity $Html

    $Html = $Html -replace '%%TABLE_START%%', '' -replace '%%TABLE_END%%', ''
    $Html = $Html -replace '%%LIST_START%%', '' -replace '%%LIST_END%%', ''
    $Html = $Html -replace '%%LT%%', '<' -replace '%%GT%%', '>'
    $Html = [regex]::Replace($Html, '(\r?\n){3,}', "`n`n")

    return $Html.Trim()
}

function Get-UrlAsMarkdown {
    <#
    .SYNOPSIS
        Fetches a web page and converts its HTML content to clean Markdown suitable for LLM context.

    .DESCRIPTION
        Downloads the HTML from a given URL, strips scripts/styles/nav/footer elements,
        and converts the meaningful content to well-structured Markdown with headers,
        tables, lists, links, and blockquotes preserved.

        Writes the Markdown to a file when -OutputPath is given or -Save is set; otherwise
        the Markdown is returned on the pipeline.

    .PARAMETER Url
        The URL of the web page to convert.

    .PARAMETER OutputPath
        Optional. File path to save the markdown output. Implies -Save.

    .PARAMETER Save
        Save to a file. If -OutputPath is omitted, a filename is generated from the URL slug
        in the current directory.

    .PARAMETER IncludeSource
        If set, adds a source URL line at the top of the markdown.

    .EXAMPLE
        Get-UrlAsMarkdown "https://blog.cissp.app/cissp-study-guide-2026"

    .EXAMPLE
        Get-UrlAsMarkdown -Url "https://example.com/article" -OutputPath "article.md" -IncludeSource
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Url,

        [Parameter(Position = 1)]
        [string]$OutputPath,

        [switch]$Save,

        [switch]$IncludeSource
    )

    process {
        Write-Verbose "Fetching: $Url"

        try {
            $response = Invoke-WebRequest -Uri $Url -TimeoutSec 30 -ErrorAction Stop
        } catch {
            Write-Error "Failed to fetch URL '$Url': $_"
            return
        }

        $html = $response.Content

        $titleMatch = [regex]::Match($html, '<title\b[^>]*>(.*?)</title>', [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $pageTitle = if ($titleMatch.Success) { (Get-HtmlTextContent $titleMatch.Groups[1].Value).Trim() } else { '' }

        Write-Verbose 'Converting to Markdown...'
        $markdown = ConvertFrom-HtmlToMarkdown $html

        $document = New-Object System.Text.StringBuilder

        if ($IncludeSource) {
            [void]$document.AppendLine("> Source: $Url")
            [void]$document.AppendLine('')
        }

        if ($pageTitle -and -not ($markdown -match '^\s*# ')) {
            [void]$document.AppendLine("# $pageTitle")
            [void]$document.AppendLine('')
        }

        [void]$document.Append($markdown)
        $content = $document.ToString()

        if (-not $Save -and -not $OutputPath) {
            return $content
        }

        $path = $OutputPath
        if (-not $path) {
            $slug = ([System.Uri]$Url).AbsolutePath.Trim('/')
            $slug = $slug -replace '[^a-zA-Z0-9\-]', '-'
            $slug = $slug -replace '-+', '-'
            $slug = $slug.Trim('-')
            if ([string]::IsNullOrWhiteSpace($slug)) { $slug = 'page' }
            $path = "$slug.md"
        }

        Set-Content -Path $path -Value $content -Encoding UTF8 -NoNewline
        Write-Verbose "Saved to: $path ($(($content -split "`n").Count) lines, $($content.Length) characters)"

        return Get-Item -LiteralPath $path
    }
}

Export-ModuleMember -Function Get-UrlAsMarkdown
