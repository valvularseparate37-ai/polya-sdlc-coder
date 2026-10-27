# install.ps1
# Interactive installation script for polya-sdlc-coder (Windows Terminal/PowerShell)
# Requires -Version 5.1

$ErrorActionPreference = 'Stop'

$repoOwner = 'valvularseparate37-ai'
$repoName = 'polya-sdlc-coder'
$repoGitUrl = "https://github.com/$repoOwner/$repoName.git"
$repoZipUrl = "https://github.com/$repoOwner/$repoName/archive/refs/heads/main.zip"

Write-Host '=== Polya SDLC Coder - Installer ===' -ForegroundColor Cyan

$targetPath = Read-Host 'Enter your target project path (default: .)'
if ([string]::IsNullOrWhiteSpace($targetPath)) { $targetPath = '.' }

try {
    $targetPath = (Resolve-Path -Path $targetPath).Path
} catch {
    Write-Host "Error: Target directory '$targetPath' not found." -ForegroundColor Red
    exit 1
}

Write-Host "Target directory: $targetPath" -ForegroundColor Yellow

$tempRoot = Join-Path $env:TEMP ("polya-sdlc-" + [System.Guid]::NewGuid().ToString('N'))
$tempCloneDir = Join-Path $tempRoot 'repo'
$tempZip = Join-Path $tempRoot 'archive.zip'

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $sourceContentDir = $null
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue

    if ($null -ne $gitCmd) {
        Write-Host 'Cloning repository from GitHub (shallow clone)...' -ForegroundColor Cyan
        git clone --depth=1 -q $repoGitUrl $tempCloneDir
        $sourceContentDir = $tempCloneDir
    } else {
        Write-Host 'Git not found. Downloading repository ZIP...' -ForegroundColor Yellow
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $repoZipUrl -OutFile $tempZip -UseBasicParsing

        Write-Host 'Extracting files...' -ForegroundColor Cyan
        Expand-Archive -Path $tempZip -DestinationPath $tempRoot

        $candidateDirs = Get-ChildItem -Path $tempRoot -Directory
        foreach ($candidate in $candidateDirs) {
            $agentDir = Join-Path $candidate.FullName '.agents'
            $agentsFile = Join-Path $candidate.FullName 'AGENTS.md'
            if ((Test-Path $agentDir) -and (Test-Path $agentsFile)) {
                $sourceContentDir = $candidate.FullName
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($sourceContentDir) -or !(Test-Path $sourceContentDir)) {
        Write-Host 'Error: Failed to locate the downloaded repository contents.' -ForegroundColor Red
        exit 1
    }

    $srcDir = Join-Path $sourceContentDir '.agents'
    $srcAgents = Join-Path $sourceContentDir 'AGENTS.md'

    if (!(Test-Path $srcDir) -or !(Test-Path $srcAgents)) {
        Write-Host 'Error: Expected .agents folder and AGENTS.md in the downloaded repository.' -ForegroundColor Red
        exit 1
    }

    Write-Host 'Ready to install: Polya SDLC Coder' -ForegroundColor Green

    Write-Host ''
    Write-Host 'Select the AI Assistant platform you want to install in your project:' -ForegroundColor Cyan
    Write-Host '1) Standard Platforms (GitHub Copilot, Antigravity, OpenCode, CommandCode, Codex, Pi, OMP) -> installs to .agents/'
    Write-Host '2) Claude Code -> installs to .claude/'
    Write-Host '3) Cursor -> installs to .cursor/'
    Write-Host '4) All Platforms (Install to .agents/, .claude/, and .cursor/)'
    Write-Host ''

    $choice = Read-Host 'Enter your platform choice (1-4, default: 1)'
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }

    $destDirs = @()
    switch ($choice) {
        '1' { $destDirs = @('.agents') }
        '2' { $destDirs = @('.claude') }
        '3' { $destDirs = @('.cursor') }
        '4' { $destDirs = @('.agents', '.claude', '.cursor') }
        default {
            Write-Host 'Invalid choice. Process aborted.' -ForegroundColor Red
            exit 1
        }
    }

    foreach ($dstDirName in $destDirs) {
        $dstDir = Join-Path $targetPath $dstDirName

        if (Test-Path $dstDir) {
            $confirmFolder = Read-Host "Folder '$dstDirName' already exists in target. Overwrite entire folder? (y/N)"
            if ($confirmFolder -notmatch '^[Yy]$') {
                Write-Host "Skipping copy of '$dstDirName'..." -ForegroundColor Yellow
                continue
            }

            Remove-Item -Path $dstDir -Recurse -Force
        }

        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        Copy-Item -Path (Join-Path $srcDir '*') -Destination $dstDir -Recurse -Force

        if ($dstDirName -ne '.agents') {
            $secondaryMemory = Join-Path $dstDir 'instructions\memory.instructions.md'
            if (Test-Path $secondaryMemory) {
                Remove-Item -Path $secondaryMemory -Force -ErrorAction SilentlyContinue
            }
        }

        Write-Host "Successfully copied agents configuration to $dstDir" -ForegroundColor Green
    }

    $dstAgents = Join-Path $targetPath 'AGENTS.md'
    if (Test-Path $srcAgents) {
        if (Test-Path $dstAgents) {
            Write-Host "File 'AGENTS.md' already exists in target." -ForegroundColor Yellow
            $agentsChoice = Read-Host 'Do you want to: [k]eep existing, [r]eplace with template, or [m]erge them? (K/r/m)'

            if ($agentsChoice -match '^[Rr]$') {
                $bakPath = $dstAgents + '.bak'
                Copy-Item -Path $dstAgents -Destination $bakPath -Force
                Copy-Item -Path $srcAgents -Destination $dstAgents -Force
                Write-Host "Replaced AGENTS.md. Old version backed up at: $bakPath" -ForegroundColor Green
            } elseif ($agentsChoice -match '^[Mm]$') {
                $bakPath = $dstAgents + '.bak'
                Copy-Item -Path $dstAgents -Destination $bakPath -Force

                $currentDate = Get-Date -Format 'yyyy-MM-dd'
                $mergeHeader = "# --- MERGED POLYA TEMPLATE (Added on $currentDate) ---"
                $newTemplateContent = Get-Content -Path $srcAgents -Raw
                $newMergeBlock = "$mergeHeader`r`n`r`n$newTemplateContent"

                $existingContent = Get-Content -Path $dstAgents -Raw
                $mergePattern = '(?s)# --- MERGED (?:POLYA )?TEMPLATE.*$'
                if ($existingContent -match $mergePattern) {
                    $baseContent = ($existingContent -replace $mergePattern, '').TrimEnd()
                    Write-Host 'Replacing previous merged template block in AGENTS.md...' -ForegroundColor Yellow
                } else {
                    $baseContent = $existingContent.TrimEnd()
                }

                $updatedContent = "$baseContent`r`n`r`n$newMergeBlock"
                Set-Content -Path $dstAgents -Value $updatedContent -Encoding utf8
                Write-Host "Merged new template into AGENTS.md. Backup created at: $bakPath" -ForegroundColor Green
            } else {
                Write-Host "Skipping copy of 'AGENTS.md'..." -ForegroundColor Yellow
            }
        } else {
            Copy-Item -Path $srcAgents -Destination $targetPath -Force
            Write-Host "Successfully copied AGENTS.md to $targetPath" -ForegroundColor Green
        }
    } else {
        Write-Host "Warning: AGENTS.md not found in source repository." -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '[OK] Installation completed successfully!' -ForegroundColor Green
    Write-Host '[IMPORTANT]: Please review AGENTS.md in your project to:' -ForegroundColor Yellow
    Write-Host '1. Customize the project name on the first line so that AI agents can recognize your project context.' -ForegroundColor Yellow
    Write-Host '2. Change the language preference in the "## Communication" section if necessary.' -ForegroundColor Yellow
    Write-Host 'Next Steps with Pólya SDLC:' -ForegroundColor Cyan
    Write-Host '- Start by typing /to-ask-help for interactive Socratic triage guidance and intent routing.' -ForegroundColor Cyan
    Write-Host '- Type /to-explore to survey and discover problem spaces (Phase 0).' -ForegroundColor Cyan
    Write-Host '- In an existing codebase, run /to-map to document architecture topography into docs/ARCHITECTURE.md.' -ForegroundColor Cyan
    Write-Host ''
} finally {
    if (Test-Path $tempRoot) {
        Write-Host 'Cleaning up temporary files...' -ForegroundColor Cyan
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
