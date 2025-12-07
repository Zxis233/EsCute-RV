# 清理仿真生成的文件
Write-Host "========== 清理 ../../prj/icarus 和 ../../prj/netlist 仿真文件 ==========" -ForegroundColor Green

$targetPaths = @("../../prj/icarus", "../../prj/netlist")
$extensions = @("*.out", "*.vvp", "*.vcd", "*.view", "*.ys", "*.log", "*.json")
$cleanedCount = 0

foreach ($targetPath in $targetPaths) {
    foreach ($ext in $extensions) {
        $files = Get-ChildItem -Path $targetPath -Filter $ext -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            Write-Host "删除: $($file.FullName)" -ForegroundColor Yellow
            Remove-Item $file.FullName -Force
            $cleanedCount++
        }
    }
}

if ($cleanedCount -eq 0) {
    Write-Host "`n没有找到需要清理的文件" -ForegroundColor Cyan
} else {
    Write-Host "`n清理完成！共删除 $cleanedCount 个文件" -ForegroundColor Green
}
