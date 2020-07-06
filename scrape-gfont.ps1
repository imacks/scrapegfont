<#
    .SYNOPSIS
        A quick script to grab Google fonts for self hosting.

    .DESCRIPTION
        This script analyzes the CSS files returned by Google Font to download all font files (including MacOS variants). It is also able to generate css files so you can self host these fonts in your web application.

    .EXAMPLE
        .\scrape-gfont.ps1 -DownloadCss -Path .\ -FontFamily 'IBM Plex Sans' -FontStyle ital,wght@0,100;0,200;0,300;0,400;0,500;0,600;0,700;1,100;1,200;1,300;1,400;1,500;1,600;1,700'

        DESCRIPTION
        -----------
        Downloads CSS files from Google font server. Parse the files to get a list of font files. Generated files are saved to ".\".

        Get the font style by going to Google fonts website, select the styles you want, and examine the embed link generated.

    .EXAMPLE
        .\scrape-gfont.ps1 -WriteCss -Path .\ -Destination 'assets/fonts' -RelativeFontDirectory 'ibmplexsans/v7'

        DESCRIPTION
        -----------
        Create "assets/fonts/ibmplexsans.{|legacy|mac|legacy.mac}.css" files based on CSS files downloaded in the previous step.

        Generated CSS files will reference font url by path "ibmplexsans/v7/...".

    .EXAMPLE
        .\scrape-gfont.ps1 -DownloadFont -Path .\ -Destination 'assets/fonts/ibmplexsans/v7'

        DESCRIPTION
        -----------
        Read ".\*.fonts" files and download them to "assets/fonts/ibmplexsans/v7/*".
#>
[CmdletBinding(DefaultParameterSetName = 'DownloadCssSet')]
Param(
    [Parameter(Mandatory, ParameterSetName = 'DownloadCssSet')]
    [string]$FontFamily,

    [Parameter(Mandatory, ParameterSetName = 'DownloadCssSet')]
    [string]$FontStyle,

    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory, ParameterSetName = 'WriteCssSet')]
    [Parameter(Mandatory, ParameterSetName = 'DownloadFontSet')]
    [string]$Destination,

    [Parameter(Mandatory, ParameterSetName = 'WriteCssSet')]
    [string]$RelativeFontDirectory,

    [Parameter(Mandatory, ParameterSetName = 'DownloadCssSet')]
    [switch]$DownloadCss,

    [Parameter(Mandatory, ParameterSetName = 'DownloadFontSet')]
    [switch]$DownloadFont,

    [Parameter(Mandatory, ParameterSetName = 'WriteCssSet')]
    [switch]$WriteCss,

    [Parameter(ParameterSetName = 'DownloadFontSet')]
    [switch]$WhatIf,

    [Parameter()]
    [switch]$Force
)

$fontFamily = 'IBM Plex Sans'
$fontStyles = 'ital,wght@0,100;0,200;0,300;0,400;0,500;0,600;0,700;1,100;1,200;1,300;1,400;1,500;1,600;1,700'

$apiBaseUrl = 'https://fonts.googleapis.com/css2'
$gstaticBaseUrl = 'https://fonts.gstatic.com/s/'
$svgFontBaseUrl = 'https://fonts.gstatic.com/l/font?'

$uaMap = @{
    # woff2 (with mac)
    'woff2' = 'Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.106 Safari/537.36'
    'woff2_mac' = 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.10; rv:62.0) Gecko/20100101 Firefox/62.0'

    # woff2 no unicode (with mac)
    'woff2old' = 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:40.0) Gecko/20100101 Firefox/40.1'
    'woff2old_mac' = 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) Gecko/20100101 Firefox/40.1'

    # woff (with mac)
    'woff' = 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36'
    'woff_mac' = 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/418 (KHTML, like Gecko) Safari/417.9.2'

    # woff no unicode (with mac)
    'woffold' = 'Mozilla/4.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36'
    'woffold_mac' = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.124 Safari/537.36'

    # ttf (with mac)
    'ttf' = 'Mozilla/5.0'
    'ttf_mac' = 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X 10_4_11; en) AppleWebKit/528.4+ (KHTML, like Gecko) Version/4.0dp1 Safari/526.11.2'

    # svg
    'svg' = '(iPad) AppleWebKit/534'

    # eot
    'eot' = 'MSIE 8.0'
}

$cssUrl = '{0}?family={1}:{2}' -f $apiBaseUrl, ($fontFamily.Replace(' ', '+')), $fontStyles

if ($DownloadCss)
{
    $uaMap.Keys | ForEach-Object {
        $ua = $uaMap."$_"
        $uaName = $_
        $cssFile = Join-Path $Path -ChildPath ('{0}.css' -f $uaName)
        $fontFile = Join-Path $Path -ChildPath ('{0}.fonts' -f $uaName)

        if ((Test-Path $cssFile) -and (Test-Path $fontFile) -and -not $Force)
        {
            Write-Warning ('Skip existing {0}' -f $uaName)
        }
        else
        {
            $css = wget $cssUrl -UseBasicParsing -UserAgent $ua | select -expand Content

            # ... url(...) format('...') ...
            # ... url(...) ...
            $fontUrls = $css -split "`n" | where { $_ -like '*url(*' } | % {
                $_.Substring($_.IndexOf('url(') + 4).Split(')')[0]
            }

            $css | Set-Content -Path $cssFile
            dir $cssFile

            $fontUrls | Set-Content -Path $fontFile
            dir $fontFile
        }
    }
}

if ($WriteCss)
{
    $folderName = Split-Path $RelativeFontDirectory -Parent

    # css for modern browsers
    @('woff2', 'woff2_mac') | % {
        $css = Get-Content (Join-Path $Path -ChildPath "$_.css") -Raw
        $cssFile = '{0}{1}.css' -f $folderName, $(if ($_ -like '*_mac') { '.mac' } else { '' })
        $cssFile = Join-Path $Destination -ChildPath $cssFile

        $css.Replace($gstaticBaseUrl, '') | Set-Content -Path $cssFile
        dir $cssFile
    }

    $subfonts = @{}
    @('woff2old', 'woffold', 'ttf', 'svg', 'eot') | ForEach-Object {
        $css = Get-Content (Join-Path $Path -ChildPath "$_.css")

        if ($_ -eq 'eot')
        {
            #todo
        }
        else
        {
            $srcLines = $css | where { $_ -like '*src:*' }
            $srcLines | ForEach-Object {
                $srcLine = $_

                $subfont = $srcLine -split ',' | where { $_ -like '*local(*' } | select -First 1 | % {
                    $_.Substring($_.IndexOf('local(') + 'local('.Length).Split(')')[0].Trim("'")
                }
                $subfontUrl = $srcLine -split ',' | where { $_ -like '*url(*' } | select -First 1 | % {
                    $_.Substring($_.IndexOf('url(') + 'url('.Length).Split(')')[0]
                }

                if ($subfonts.ContainsKey($subfont))
                {
                    $subfonts."$subfont" += $subfontUrl
                }
                else
                {
                    $subfonts."$subfont" = @($subfontUrl)
                }
            }
        }
    }

    @('woff2old', 'woff2old_mac') | ForEach-Object {
        $css = Get-Content (Join-Path $Path -ChildPath ('{0}.css' -f $_))
        $cssOut = @()

        $css | ForEach-Object {
            if ($_ -like '*src:*')
            {
                $srcLine = $_

                $subfont = $srcLine -split ',' | where { $_ -like '*local(*' } | select -First 1 | % {
                    $_.Substring($_.IndexOf('local(') + 'local('.Length).Split(')')[0].Trim("'")
                }

                # src: local('...'), local('...'), <...>
                $newSrcLines = @(
                    $srcLine.Substring(0, $srcLine.IndexOf('url('))
                )

                $subfontUrls = $subfonts."$subfont" | ForEach-Object {
                    $fontType = $_.Substring($_.LastIndexOf('.') + 1)
                    $fontUrl = '{0}/{1}' -f $RelativeFontDirectory, (Split-Path $_ -Leaf)

                    if ($fontType -eq 'ttf')
                    {
                        $fontType = 'truetype'
                    }
                    elseif ($_.StartsWith($svgFontBaseUrl))
                    {
                        $fontType = 'svg'
                        $fontBaseName = $_.Substring($svgFontBaseUrl.Length).Split('&') | where { $_ -like 'skey=*' } | % { $_.Split('=')[1] }
                        $fontUrl = '{0}/{1}.svg#{1}' -f $RelativeFontDirectory, $fontBaseName, $_.Substring($_.LastIndexOf('#') + 1)
                    }

                    "    url({0}) format('{1}')" -f $fontUrl, $fontType
                }

                $newSrcLines += $subfontUrls -join ",`n"
                $newSrcLines[-1] = $newSrcLines[-1] + ';'

                $cssOut += $newSrcLines
            }
            else
            {
                $cssOut += $_
            }
        }

        $cssFile = '{0}{1}.legacy.css' -f $folderName, $(if ($_ -like '*_mac') { '.mac' } else { '' })
        $cssFile = Join-Path $Destination -ChildPath $cssFile
        $cssOut | Set-Content -Path $cssFile
        dir $cssFile
    }
}

if ($DownloadFont)
{
    $fontDir = $Destination

    $dlFileList = dir (Join-Path $Path -ChildPath '*.fonts') -File
    $dlFileList | ForEach-Object {
        $fileList = Get-Content $_
        $fileList | ForEach-Object {
            $srcUrl = $_

            if ($srcUrl.StartsWith($svgFontBaseUrl))
            {
                $fontBaseName = $srcUrl.Substring($svgFontBaseUrl.Length).Split('&') | where { $_ -like 'skey=*' } | % { $_.Split('=')[1] }
                $outFile = '{0}.svg' -f $fontBaseName
                $outFile = Join-Path $fontDir -ChildPath $outFile
            }
            else
            {
                $outFile = Join-Path $fontDir -ChildPath (Split-Path $srcUrl -Leaf)
            }

            if ((Test-Path $outFile) -and -not $Force)
            {
                Write-Warning ("Not override font file {0}" -f $outFile)
            }
            else
            {
                $outDirectory = Split-Path $outFile -Parent
                if (-not (Test-Path $outDirectory))
                {
                    if ($WhatIf)
                    {
                        Write-Output ('Create directory {0}' -f $outDirectory)
                    }
                    else
                    {
                        md $outDirectory -Force
                    }
                }

                if ($WhatIf)
                {
                    Write-Output ('Download {0} to {1}' -f $srcUrl, $outFile)                
                }
                else
                {
                    wget $srcUrl -OutFile $outFile
                    dir $outFile
                }
            }
        }
    }
}
