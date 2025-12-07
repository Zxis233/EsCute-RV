# 简化的 Iverilog 仿真脚本 (不包含 IP 核)
# 注意: 需要提供 IROM 和 DRAM 的行为模型

# 声明命令行参数
param(
    [string]$IROM = "",
    [string]$DRAM = ""
)
Set-Location "$PSScriptRoot/../src"

Write-Host "========== Iverilog 简化仿真 ==========" -ForegroundColor Green

# 定义所有需要编译的文件
$sourceFiles = @(
    "defines.vh",
    "tb_miniRV_SoC.v",
    "miniRV_SoC.v",
    "myCPU.v",
    "PC.v",
    "NPC.v",
    "NPC_JUMP.v",
    "SEXT.v",
    "RF.v",
    "ALU.v",
    "ALU_MUX.v",
    "ALU_MUX_A.v",
    "RF_MUX.v",
    "DRAM_MUX.v",
    "CONTROL.v",
    "HAZARD.v",
    "Bridge.v",
    "REG_IF_ID.v",
    "REG_ID_EX.v",
    "REG_EX_MEM.v",
    "REG_MEM_WB.v",
    "DIG.v",
    "LED.v",
    "timer.v",
    "IROM.v",
    "DRAM.v"
)

# 检查文件是否存在
Write-Host "`n检查源文件..." -ForegroundColor Yellow
$missingFiles = @()
foreach ($file in $sourceFiles) {
    if (-not (Test-Path $file)) {
        $missingFiles += $file
        Write-Host "  缺失: $file" -ForegroundColor Red
    } else {
        Write-Host "  找到: $file" -ForegroundColor Gray
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "`n警告: 以下文件缺失:" -ForegroundColor Yellow
    $missingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host "`n注意: IROM 和 DRAM 是 IP 核，需要提供行为模型或从项目中生成" -ForegroundColor Cyan
}

# 清理旧文件
if (Test-Path "../../prj/icarus/tb_miniRV_SoC.vcd") { Remove-Item "../../prj/icarus/tb_miniRV_SoC.vcd" }
if (Test-Path "../../prj/icarus/tb_miniRV_SoC.vvp") { Remove-Item "../../prj/icarus/tb_miniRV_SoC.vvp" }

# 编译
Write-Host "`n开始编译..." -ForegroundColor Yellow
$args = @("-o", "tb_miniRV_SoC.vvp", "-g2012", "-DRUN_TRACE", "-I", ".") + $sourceFiles
& iverilog $args

if ($LASTEXITCODE -eq 0) {
    Write-Host "编译成功！" -ForegroundColor Green
    Write-Host "`n运行仿真..." -ForegroundColor Yellow
    
    # 支持通过命令行参数传递 IROM/DRAM 文件
    # 用法: .\run_sim_simple.ps1 -IROM test.hex -DRAM data.hex
    $vvpArgs = @("../../prj/icarus/tb_miniRV_SoC.vvp")
    if ($IROM -ne "") { 
        $vvpArgs += "+IROM=$IROM"
        Write-Host "使用自定义 IROM 文件: $IROM" -ForegroundColor Cyan
    }
    if ($DRAM -ne "") { 
        $vvpArgs += "+DRAM=$DRAM"
        Write-Host "使用自定义 DRAM 文件: $DRAM" -ForegroundColor Cyan
    }
    
    & vvp $vvpArgs
    
    if (Test-Path "tb_miniRV_SoC.vcd") {
        Write-Host "`n仿真完成！波形文件: tb_miniRV_SoC.vcd" -ForegroundColor Green
    }
} else {
    Write-Host "`n编译失败！" -ForegroundColor Red
}
