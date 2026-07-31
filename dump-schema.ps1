# dump-schema.ps1
# Run this from your project root after applying any new migration.
# It dumps the current local Supabase schema to supabase/schema.sql
# and stages it ready for your next commit.
#
# Usage:
#   .\dump-schema.ps1
#
# Typical workflow:
#   1. Add a new migration file to supabase/migrations/
#   2. supabase db push
#   3. .\dump-schema.ps1
#   4. git commit -m "docs: update schema.sql after <migration name>"

Write-Host "Dumping local Supabase schema..." -ForegroundColor Cyan

supabase db dump --local -f supabase/schema.sql

if ($LASTEXITCODE -ne 0) {
  Write-Host "ERROR: supabase db dump failed. Is your local Supabase instance running?" -ForegroundColor Red
  Write-Host "Run: supabase start" -ForegroundColor Yellow
  exit 1
}

Write-Host "Schema dumped to supabase/schema.sql" -ForegroundColor Green

git add supabase/schema.sql
Write-Host "Staged supabase/schema.sql for commit." -ForegroundColor Green
Write-Host ""
Write-Host "Next step: git commit -m `"docs: update schema.sql after <migration name>`"" -ForegroundColor Yellow
