BeforeAll {
    $script:ManifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'UrlAsMarkdown', 'UrlAsMarkdown.psd1'
    Import-Module $script:ManifestPath -Force
}

AfterAll {
    Remove-Module UrlAsMarkdown -Force -ErrorAction SilentlyContinue
}

Describe 'Module surface' {

    It 'has a valid manifest' {
        { Test-ModuleManifest -Path $script:ManifestPath } | Should -Not -Throw
    }

    It 'exports only Get-UrlAsMarkdown' {
        (Get-Module UrlAsMarkdown).ExportedFunctions.Keys | Should -Be @('Get-UrlAsMarkdown')
    }

    It 'keeps helper <_> private' -ForEach @(
        'Get-CommentFreeHtml'
        'Get-TagBlockFreeHtml'
        'ConvertFrom-HtmlEntity'
        'Get-HtmlTextContent'
        'ConvertTo-MarkdownTable'
        'ConvertTo-MarkdownList'
        'ConvertFrom-HtmlToMarkdown'
    ) {
        Get-Command $_ -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'provides comment-based help with an example' {
        $help = Get-Help Get-UrlAsMarkdown
        $help.Synopsis | Should -Not -BeNullOrEmpty
        $help.Examples.Example.Count | Should -BeGreaterThan 0
    }
}

Describe 'HTML to Markdown conversion' {

    BeforeAll {
        function Convert ([string]$Html) {
            InModuleScope UrlAsMarkdown -Parameters @{ Html = $Html } {
                ConvertFrom-HtmlToMarkdown $Html
            }
        }
    }

    Context 'Block elements' {

        It 'converts h<_> to the matching ATX heading' -ForEach 1, 2, 3, 4, 5, 6 {
            $level = $_
            $md = Convert "<body><h$level>Title</h$level></body>"
            $md | Should -Be ('#' * $level + ' Title')
        }

        It 'converts paragraphs to bare text' {
            Convert '<body><p>Hello world.</p></body>' | Should -Be 'Hello world.'
        }

        It 'drops empty paragraphs' {
            Convert '<body><p>  </p><p>Kept.</p></body>' | Should -Be 'Kept.'
        }

        It 'converts blockquotes' {
            Convert '<body><blockquote>Quoted.</blockquote></body>' | Should -Be '> Quoted.'
        }

        It 'converts hr to a thematic break' {
            Convert '<body><p>a</p><hr><p>b</p></body>' | Should -Be "a`n`n---`n`nb"
        }

        It 'converts br to a newline' {
            Convert '<body><p>one</p>two<br>three</body>' | Should -Match 'two\s*\r?\nthree'
        }
    }

    Context 'Lists' {

        It 'converts an unordered list' {
            Convert '<body><ul><li>one</li><li>two</li></ul></body>' | Should -Be "- one`n- two"
        }

        It 'converts an ordered list with incrementing numbers' {
            Convert '<body><ol><li>one</li><li>two</li><li>three</li></ol></body>' |
                Should -Be "1. one`n2. two`n3. three"
        }

        It 'skips empty list items' {
            Convert '<body><ul><li></li><li>kept</li></ul></body>' | Should -Be '- kept'
        }
    }

    Context 'Tables' {

        It 'emits a header separator row' {
            $md = Convert '<body><table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table></body>'
            $md | Should -Be "| A | B |`n| --- | --- |`n| 1 | 2 |"
        }

        It 'sizes the separator to the header cell count' {
            $md = Convert '<body><table><tr><th>A</th><th>B</th><th>C</th></tr></table></body>'
            ($md -split "`n")[1] | Should -Be '| --- | --- | --- |'
        }

        It 'escapes pipes inside cells' {
            $md = Convert '<body><table><tr><td>a|b</td></tr></table></body>'
            $md | Should -Match '\\\|'
        }

        It 'returns nothing for a table with no rows' {
            Convert '<body><table></table></body>' | Should -BeNullOrEmpty
        }
    }

    Context 'Inline elements' {

        It 'converts links to inline Markdown' {
            Convert '<body><p><a href="https://example.com">text</a></p></body>' |
                Should -Be '[text](https://example.com)'
        }

        It 'unwraps <_> links to plain text' -ForEach '#anchor', 'javascript:void(0)' {
            Convert "<body><p><a href=`"$_`">text</a></p></body>" | Should -Be 'text'
        }

        It 'drops links with no text' {
            Convert '<body><p>kept<a href="https://example.com"></a></p></body>' | Should -Be 'kept'
        }

        It 'converts <_> to bold' -ForEach 'strong', 'b' {
            Convert "<body><p><$_>loud</$_></p></body>" | Should -Be '**loud**'
        }

        It 'converts <_> to italic' -ForEach 'em', 'i' {
            Convert "<body><p><$_>soft</$_></p></body>" | Should -Be '*soft*'
        }

        It 'converts inline code' {
            Convert '<body><p><code>Get-Date</code></p></body>' | Should -Be '`Get-Date`'
        }

        It 'converts pre/code to a fenced block with real newlines' {
            $fence = [string][char]0x60 * 3
            Convert '<body><pre><code>Get-Date</code></pre></body>' |
                Should -Be "$fence`nGet-Date`n$fence"
        }
    }

    Context 'Content stripping' {

        It 'removes <_> blocks entirely' -ForEach 'script', 'style', 'nav', 'footer', 'header', 'noscript', 'svg', 'iframe' {
            $md = Convert "<body><$_>REMOVED</$_><p>kept</p></body>"
            $md | Should -Be 'kept'
        }

        It 'removes HTML comments' {
            Convert '<body><!-- REMOVED --><p>kept</p></body>' | Should -Be 'kept'
        }

        It 'removes a <_> chrome block' -ForEach 'sidebar', 'cookie', 'popup', 'newsletter', 'advertisement' {
            $md = Convert "<body><div class=`"$_`">REMOVED</div><p>kept</p></body>"
            $md | Should -Be 'kept'
        }

        It 'prefers <main> over surrounding chrome' {
            Convert '<body><p>outside</p><main><p>inside</p></main></body>' | Should -Be 'inside'
        }

        It 'prefers <article> when there is no <main>' {
            Convert '<body><p>outside</p><article><p>inside</p></article></body>' | Should -Be 'inside'
        }
    }

    Context 'Entities and whitespace' {

        It 'decodes named entities' {
            Convert '<body><p>a &amp; b &lt;c&gt;</p></body>' | Should -Be 'a & b <c>'
        }

        It 'keeps decoded angle brackets instead of stripping them as tags' {
            Convert '<body><p>use &lt;div&gt; here</p></body>' | Should -Be 'use <div> here'
        }

        It 'keeps decoded angle brackets inside code' {
            Convert '<body><p><code>&lt;div&gt;</code></p></body>' | Should -Be '`<div>`'
        }

        It 'decodes numeric entities' {
            Convert '<body><p>caf&#233;</p></body>' | Should -Be "caf$([char]233)"
        }

        It 'collapses runs of blank lines to at most one' {
            $md = Convert '<body><p>a</p><p>b</p><p>c</p></body>'
            $md | Should -Not -Match '\n\s*\n\s*\n'
        }

        It 'trims leading and trailing whitespace' {
            $md = Convert '<body>   <p>a</p>   </body>'
            $md | Should -Be 'a'
        }
    }
}

Describe 'Get-UrlAsMarkdown' {

    BeforeAll {
        $script:Page = @'
<html><head><title>Page Title</title></head>
<body><main><p>Body text.</p></main></body></html>
'@
    }

    BeforeEach {
        Mock -ModuleName UrlAsMarkdown Invoke-WebRequest {
            [pscustomobject]@{ Content = $script:Page }
        }
    }

    It 'returns Markdown as a string when no output is requested' {
        $result = Get-UrlAsMarkdown -Url 'https://example.com/article'
        $result | Should -BeOfType [string]
        $result | Should -Match 'Body text\.'
    }

    It 'prepends the page title as an H1' {
        Get-UrlAsMarkdown -Url 'https://example.com/article' |
            Should -Match '^# Page Title'
    }

    It 'does not add a title when the content already starts with an H1' {
        Mock -ModuleName UrlAsMarkdown Invoke-WebRequest {
            [pscustomobject]@{ Content = '<html><head><title>T</title></head><body><h1>Own</h1></body></html>' }
        }
        $result = Get-UrlAsMarkdown -Url 'https://example.com/article'
        $result | Should -Be '# Own'
    }

    It 'omits the source line by default' {
        Get-UrlAsMarkdown -Url 'https://example.com/article' | Should -Not -Match '> Source:'
    }

    It 'adds the source line with -IncludeSource' {
        Get-UrlAsMarkdown -Url 'https://example.com/article' -IncludeSource |
            Should -Match '^> Source: https://example\.com/article'
    }

    It 'writes to -OutputPath and returns a FileInfo' {
        $path = Join-Path $TestDrive 'out.md'
        $result = Get-UrlAsMarkdown -Url 'https://example.com/article' -OutputPath $path
        $result | Should -BeOfType [System.IO.FileInfo]
        $path | Should -Exist
        (Get-Content $path -Raw) | Should -Match 'Body text\.'
    }

    It 'derives a filename from the URL slug with -Save' {
        Push-Location $TestDrive
        try {
            Get-UrlAsMarkdown -Url 'https://example.com/blog/my-post' -Save | Out-Null
            Join-Path $TestDrive 'blog-my-post.md' | Should -Exist
        } finally {
            Pop-Location
        }
    }

    It 'falls back to page.md for a root URL with -Save' {
        Push-Location $TestDrive
        try {
            Get-UrlAsMarkdown -Url 'https://example.com/' -Save | Out-Null
            Join-Path $TestDrive 'page.md' | Should -Exist
        } finally {
            Pop-Location
        }
    }

    It 'accepts URLs from the pipeline' {
        $results = 'https://example.com/a', 'https://example.com/b' | Get-UrlAsMarkdown
        $results.Count | Should -Be 2
    }

    It 'writes a non-terminating error when the fetch fails' {
        Mock -ModuleName UrlAsMarkdown Invoke-WebRequest { throw 'boom' }
        $err = $null
        Get-UrlAsMarkdown -Url 'https://example.com/article' -ErrorVariable err -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
        $err | Should -Not -BeNullOrEmpty
        ($err | ForEach-Object { $_.ToString() }) -join "`n" | Should -Match 'Failed to fetch URL'
    }
}
