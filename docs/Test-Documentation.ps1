[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$files = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.md' -File)
$files += Get-Item -LiteralPath (Join-Path $repoRoot 'README.md'), (Join-Path $repoRoot 'CONTRIBUTING.md'), (Join-Path $repoRoot 'SECURITY.md')
$linkCount = 0
$mermaidCount = 0
foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $insideFence = $false
    $outside = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($content -split '\r?\n')) {
        if ($line -match '^\s*```') {
            $insideFence = -not $insideFence
            if ($line -match '^```mermaid\s*$') { $mermaidCount++ }
            continue
        }
        if (-not $insideFence) { $outside.Add($line) }
    }
    if ($insideFence) { throw "Bloc Markdown non ferme : $($file.Name)" }
    foreach ($match in [regex]::Matches(($outside -join "`n"), '\[[^\]]+\]\(([^)]+)\)')) {
        $target = $match.Groups[1].Value.Trim('<','>')
        if ($target -match '^(https?://|mailto:|#)') { continue }
        $relative = ($target -split '#', 2)[0]
        $resolved = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $relative))
        if (-not $resolved.StartsWith($repoRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Lien hors depot : $($file.Name) -> $target"
        }
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Lien absent : $($file.Name) -> $target" }
        $linkCount++
    }
}
"Documentation verifiee : $($files.Count) fichiers, $linkCount liens locaux, $mermaidCount schemas Mermaid (rendu non teste)."
