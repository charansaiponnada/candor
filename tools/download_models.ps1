# Downloads the two Qwen GGUF models into the bundled Android assets.
# Run before building/running the app: `powershell -ExecutionPolicy Bypass -File tools/download_models.ps1`
$ErrorActionPreference = 'Stop'
$dest = Join-Path $PSScriptRoot '..\android\app\src\main\assets\models'
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$models = @(
  'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
  'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf'
)

foreach ($url in $models) {
  $file = Join-Path $dest ([System.IO.Path]::GetFileName($url))
  if (Test-Path $file) { Write-Host "Already present: $file"; continue }
  Write-Host "Downloading $file ..."
  curl.exe -L --progress-bar -o $file $url
}

Get-ChildItem $dest | ForEach-Object { "{0}  {1:N1} MB" -f $_.Name, ($_.Length / 1MB) }