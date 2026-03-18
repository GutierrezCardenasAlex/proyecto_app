param(
  [string]$Phone = "+59170000000"
)

$ErrorActionPreference = "Stop"

Write-Host "Solicitando OTP..." -ForegroundColor Cyan
$requestBody = @{
  phone = $Phone
  role = "passenger"
  fullName = "Usuario Demo"
} | ConvertTo-Json

$otpResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/auth/otp/request" `
  -Method Post `
  -ContentType "application/json" `
  -Body $requestBody

$otp = $otpResponse.otp
Write-Host "OTP recibido: $otp" -ForegroundColor Green

Write-Host "Verificando OTP..." -ForegroundColor Cyan
$verifyBody = @{
  phone = $Phone
  otp = $otp
} | ConvertTo-Json

$verifyResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/auth/otp/verify" `
  -Method Post `
  -ContentType "application/json" `
  -Body $verifyBody

Write-Host "Token emitido correctamente." -ForegroundColor Green
$verifyResponse | ConvertTo-Json -Depth 5
