# Defina os caminhos de origem e destino
$origens = "C:\", "C:\"
$pastaDestino = "C:\"
$logPath = "C:\Log_Backup\backup.log"
$reportPath = "C:\Log_Backup\backup_report.txt"

# Função para registrar atividades
function Write-Log {
    param (
        [string]$Message,
        [string]$Path
    )
    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    "$timestamp - $Message" | Out-File $Path -Append
}

function Generate-Report {
    param (
        [string]$BackupPath,
        [string]$ReportPath
    )
    $items = Get-ChildItem -Path $BackupPath -Recurse
    $totalSize = ($items | Measure-Object -Property Length -Sum).Sum / 1MB # Total size in MB
    $fileCount = ($items | Where-Object { !$_.PSIsContainer }).Count
    $folderCount = ($items | Where-Object { $_.PSIsContainer }).Count

    "Relatorio de Backup - $(Get-Date -Format 'dd-MM-yyyy HH:mm:ss')" | Out-File $ReportPath
    "-----------------------------------------------------------" | Out-File $ReportPath -Append
    "Tamanho Total do Backup: $($totalSize) MB" | Out-File $ReportPath -Append
    "Quantidade Total de Arquivos: $fileCount" | Out-File $ReportPath -Append
    "Quantidade Total de Pastas: $folderCount" | Out-File $ReportPath -Append
    "" | Out-File $ReportPath -Append
}

try {
    # Verifique se os caminhos existem
    $origens | ForEach-Object {
        $origem = $_
        if (-not (Test-Path $origem)) {
            throw "Caminho de origem nao encontrado: $origem."
        }
    }
    
    if (-not (Test-Path $pastaDestino)) {
        throw "Caminho de destino nao encontrado."
    }

    # Crie uma subpasta com a data atual
    $dataAtual = Get-Date -Format "dd-MM-yyyy"
    $pastaBackupDiario = Join-Path -Path $pastaDestino -ChildPath $dataAtual

    # Verifique se já existe um backup para o dia atual
    if (Test-Path $pastaBackupDiario) {
        throw "Ja existe um backup para o dia atual. Backup cancelado para evitar duplicamento."
    }

    # Copie cada origem para a pasta de backup diário
    $origens | ForEach-Object {
        $origem = $_
        $nomeItem = (Get-Item $origem).Name
        $destinoItem = Join-Path -Path $pastaBackupDiario -ChildPath $nomeItem

        if (Test-Path -Path $origem -PathType Container) {
            # Se for uma pasta, copie para uma subpasta com o mesmo nome
            Copy-Item -Path $origem -Destination $destinoItem -Recurse
        } else {
            # Se for um arquivo, copie diretamente para a pasta de backup diário
            Copy-Item -Path $origem -Destination $pastaBackupDiario
        }
        Write-Log -Message "Backup realizado com sucesso: $origem." -Path $logPath
        # Gere o relatório
        Generate-Report -BackupPath $pastaBackupDiario -ReportPath $reportPath
        Write-Log -Message "Relatorio de backup gerado com sucesso: $origem." -Path $logPath
    }

    # Remova backups com mais de 7 dias
    $limite = (Get-Date).AddDays(-7)
    Get-ChildItem -Path $pastaDestino -Directory | Where-Object { $_.CreationTime -lt $limite } | Remove-Item -Recurse -Force
    Write-Log -Message "Backups antigos removidos." -Path $logPath
}
catch {
    $errorMsg = "Ocorreu um erro: $($_.Exception.Message)"
    Write-Host $errorMsg -ForegroundColor Red
    Write-Log -Message $errorMsg -Path $logPath

    # Impede que o prompt feche imediatamente em caso de erro
    Write-Host "Pressione qualquer tecla para sair..."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
