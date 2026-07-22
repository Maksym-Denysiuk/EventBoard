$root = Split-Path -Parent $PSScriptRoot
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8000/")
$listener.Start()
Write-Host "Serving $root on http://localhost:8000/"

$mime = @{
  ".html" = "text/html"; ".htm" = "text/html"; ".js" = "application/javascript";
  ".css" = "text/css"; ".json" = "application/json"; ".png" = "image/png";
  ".jpg" = "image/jpeg"; ".jpeg" = "image/jpeg"; ".svg" = "image/svg+xml";
  ".ico" = "image/x-icon"
}

while ($listener.IsListening) {
  $context = $listener.GetContext()
  $req = $context.Request
  $res = $context.Response
  try {
    $path = $req.Url.AbsolutePath
    if ($path -eq "/") { $path = "/index.html" }
    $filePath = Join-Path $root ($path.TrimStart("/") -replace "/", "\")
    if (Test-Path $filePath -PathType Leaf) {
      $ext = [System.IO.Path]::GetExtension($filePath)
      $contentType = $mime[$ext]
      if (-not $contentType) { $contentType = "application/octet-stream" }
      $bytes = [System.IO.File]::ReadAllBytes($filePath)
      $res.ContentType = $contentType
      $res.ContentLength64 = $bytes.Length
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $res.StatusCode = 404
      $bytes = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    }
  } finally {
    $res.OutputStream.Close()
  }
}
