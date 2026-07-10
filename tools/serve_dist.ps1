$ErrorActionPreference = "Stop"

$DistDir = Join-Path (Get-Location) "dist"
if (-not (Test-Path -LiteralPath $DistDir)) {
    throw "dist directory not found. Run tools/export_web.ps1 first, or use GitHub Actions for cloud export."
}

Write-Host "Serving dist at http://localhost:8000"
Write-Host "Press Ctrl+C to stop."
Push-Location $DistDir
try {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:8000/")
    $listener.Start()
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $relativePath = $context.Request.Url.LocalPath.TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($relativePath)) { $relativePath = "index.html" }
        $filePath = Join-Path $DistDir $relativePath
        if (-not (Test-Path -LiteralPath $filePath)) {
            $context.Response.StatusCode = 404
            $bytes = [Text.Encoding]::UTF8.GetBytes("Not found")
        } else {
            $bytes = [IO.File]::ReadAllBytes($filePath)
            switch ([IO.Path]::GetExtension($filePath)) {
                ".html" { $context.Response.ContentType = "text/html; charset=utf-8" }
                ".js" { $context.Response.ContentType = "application/javascript" }
                ".wasm" { $context.Response.ContentType = "application/wasm" }
                ".pck" { $context.Response.ContentType = "application/octet-stream" }
                default { $context.Response.ContentType = "application/octet-stream" }
            }
        }
        $context.Response.ContentLength64 = $bytes.Length
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $context.Response.OutputStream.Close()
    }
} finally {
    if ($listener) { $listener.Stop(); $listener.Close() }
    Pop-Location
}
