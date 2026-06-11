# run.ps1 - TradingAgents-astock 快速启动脚本
# 用法: .\run.ps1            → 交互式 CLI
#       .\run.ps1 web        → Web UI
#       .\run.ps1 cli        → 交互式 CLI
#       .\run.ps1 quick SPY  → 快速分析 (DeepSeek)

param(
    [string]$Mode = "cli",
    [string]$Ticker = ""
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$hasDeepSeek = $false
$hasOpenAI = $false
$envFile = Join-Path $scriptRoot ".env"
$deepSeekKey = ""
$openAIKey = ""

if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^DEEPSEEK_API_KEY=(.+)$') {
            $deepSeekKey = $matches[1].Trim()
            if ($deepSeekKey -and $deepSeekKey -ne 'your-key-here') {
                $hasDeepSeek = $true
            }
        }
        elseif ($_ -match '^OPENAI_API_KEY=(.+)$') {
            $openAIKey = $matches[1].Trim()
            if ($openAIKey -and $openAIKey -ne 'your-key-here') {
                $hasOpenAI = $true
            }
        }
    }
}

Write-Host "=== TradingAgents-astock v0.2.13 ===" -ForegroundColor Cyan

# 检查 uv 是否可用
if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-Host "错误: 未找到 'uv' 命令。请先安装 uv (https://docs.astral.sh/uv/)" -ForegroundColor Red
    exit 1
}

switch ($Mode.ToLower()) {
    "web" {
        Write-Host "启动 Web UI (Streamlit) ..." -ForegroundColor Green
        uv run python web/launch.py
    }
    "quick" {
        if (-not $Ticker) {
            $Ticker = Read-Host "请输入A股代码或中文全称（例: 300750 或 宁德时代）"
        }
        if (-not $hasDeepSeek) {
            Write-Host "错误: .env 中未配置有效的 DEEPSEEK_API_KEY" -ForegroundColor Red
            Write-Host "请在 $envFile 中设置 DEEPSEEK_API_KEY=sk-xxx" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "快速分析: $Ticker (使用 DeepSeek)" -ForegroundColor Green
        # 使用临时 Python 脚本执行分析
        $pyScript = @"
import os
import sys
from dotenv import load_dotenv
load_dotenv()

from tradingagents.graph.trading_graph import TradingAgentsGraph
from tradingagents.default_config import DEFAULT_CONFIG

config = DEFAULT_CONFIG.copy()
config["llm_provider"] = "deepseek"
config["deep_think_llm"] = "deepseek-chat"
config["quick_think_llm"] = "deepseek-chat"
config["max_debate_rounds"] = 1
config["max_risk_discuss_rounds"] = 1

ticker = sys.argv[1] if len(sys.argv) > 1 else "$Ticker"
date = "2025-06-10"

print(f"正在分析 {ticker} ...")
ta = TradingAgentsGraph(debug=True, config=config)
_, decision = ta.propagate(ticker, date)
print("\n=== 分析结论 ===\n")
print(decision)
"@
        $tempScript = Join-Path $env:TEMP "tradingagents_quick_$(Get-Random).py"
        $pyScript | Out-File -FilePath $tempScript -Encoding utf8
        try {
            uv run python $tempScript $Ticker
        }
        finally {
            Remove-Item $tempScript -ErrorAction SilentlyContinue
        }
    }
    "cli" {
        Write-Host "启动交互式 CLI ..." -ForegroundColor Green
        if ($hasDeepSeek -and -not $hasOpenAI) {
            Write-Host "提示: 检测到 DeepSeek API Key，将使用 DeepSeek 作为默认 LLM 提供商" -ForegroundColor Yellow
        }
        uv run tradingagents
    }
    default {
        Write-Host "未知模式: $Mode" -ForegroundColor Red
        Write-Host "支持的模式: cli, web, quick" -ForegroundColor Yellow
        exit 1
    }
}