# MSMC Analysis Pipeline

## 概述

本项目包含一个完整的MSMC (Multiple Sequential Markovian Coalescent) 分析流程，用于分析中国西南地区人群的有效群体大小历史和群体分化时间。

**重要**: 本流程从**已Phased的VCF**开始分析。

---

## 人群分析设计

### 分析人群

- **目标人群**: Jino (基诺族)
- **藏族相关**: Tibetan, Qiang, Sherpa
- **基诺相关**: Hani, Lahu
- **云南北部少数民族**: Pumi, Mosuo, Naxi
- **南亚语系**: Blang, Wa, De'ang
- **壮侗语族**: Dai, Zhuang, Dong, Buyei
- **参考人群**: Han (汉族)

### 分析内容

1. **单群体分析**: 估算各人群的有效群体大小(Ne)历史
2. **跨群体分析**: 估算群体分化时间和基因流模式

---

## 完整Workflow

```
Step 1: 样本选择           → sample_lists/{pop}.txt
Step 2: 提取单样本VCF      → single_vcf/{sample}_chr*.vcf.gz
Step 2b: 处理VCF          → variant.vcf.gz + mask.bed.gz
Step 3: 生成MSMC输入       → msmc_input/{pop}_chr*.msmc
Step 4: 运行MSMC (单群体) → msmc_output/{pop}_chr*.msmc2
Step 5: 运行MSMC (跨群体) → msmc_output/cross_*.msmc2
Step 6: 可视化            → visualization/*.png
```

---

## 关键问题

### Q1: 需要vcfAllSiteParser吗?

**是的！**

提取的VCF包含所有位点(hom-ref)，需要用它生成：
- variant-only VCF (只含变异位点)
- per-sample mask (callable regions)

### Q2: Mappability Mask要按染色体拆分吗?

**是的！** 官方要求每个染色体一个mask：
- 格式: chr1.bed.gz, chr2.bed.gz, ... chr22.bed.gz
- 下载: https://share.eva.mpg.de/index.php/s/ygfMbzwxneoTPZj

---

## 使用方法

### 1. 配置

编辑 `config.sh` 文件，配置以下内容：

- `PROJECT_ROOT`: 项目根目录
- `PHASED_VCF`: 已Phased的VCF文件路径
- `SAMPLE_INFO`: 样本信息文件
- `MAP_MASK`: Mappability mask路径 (按染色体命名)
- `N_SAMPLES_PER_POP`: 每人群选取的样本数
- `CHROMOSOMES`: 要分析的染色体

### 2. 运行完整流程

```bash
# 提交到集群
sbatch run_pipeline.sh

# 或者本地运行
bash run_pipeline.sh
```

### 3. 分步运行

```bash
# Step 1: 样本选择
bash 01_select_samples.sh

# Step 2: 提取单样本VCF
bash 02_extract_single_vcf.sh

# Step 2b: 处理VCF (生成variant + mask)
bash 02b_process_vcf.sh

# Step 3: 生成MSMC输入
bash 03_generate_msmc_input.sh

# Step 4: 运行单群体MSMC
bash 04_run_msmc.sh

# Step 5: 运行跨群体MSMC
bash 05_run_msmc_cross.sh

# Step 6: 可视化
python3 plot_msmc_ne.py
python3 plot_msmc_cross.py
```

---

## A. 可以更改和调整的参数

### 1. config.sh 中的核心参数

```bash
# =====================================
# 1.1 项目路径配置
# =====================================
PROJECT_ROOT="/share/home/litianxing/100My_Jino"
MSMC_ROOT="${PROJECT_ROOT}/116.MSMC"
WORK_DIR="${MSMC_ROOT}/true_msmc"

# =====================================
# 1.2 输入数据配置
# =====================================
# 已Phased的多样本VCF文件
PHASED_VCF="${PROJECT_ROOT}/107.IBD/data/NGS.phased.vcf.gz"

# 样本信息文件 (格式: SampleID\tPopulation\tRegion\tSubRegion)
SAMPLE_INFO="${PROJECT_ROOT}/101DataPanel/101.5Info/modified_PanAsian_info2.txt"

# Mappability mask (按染色体命名: chr1.bed.gz, chr2.bed.gz...)
MAP_MASK="${PROJECT_ROOT}/116.MSMC/mappability_mask/chr"

# =====================================
# 1.3 分析参数
# =====================================
# 每人群选取的样本数 (建议2-4)
N_SAMPLES_PER_POP=2

# 随机种子 (用于可重复抽样)
RANDOM_SEED=42

# 要分析的染色体
CHROMOSOMES=$(seq 1 22)

# MSMC运行参数
MSMC_THREADS=8
MSMC_TIME_INTERVALS="0.1*15+0.2*10+0.5*5+1*5+2*5"
```

### 2. 关键参数详解

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `N_SAMPLES_PER_POP` | 每人群随机抽取的样本数 | 2-4 |
| `RANDOM_SEED` | 随机种子，保证可重复性 | 任意整数 |
| `CHROMOSOMES` | 要分析的染色体 | 1-22 |
| `MSMC_THREADS` | MSMC运行线程数 | 8 |
| `MSMC_TIME_INTERVALS` | 时间分段模式 | 详见下方 |

#### 时间分段模式说明

```
格式: time*states+time*states+...
示例: 0.1*15+0.2*10+0.5*5+1*5+2*5

含义:
- 0.1*15  = 15个时间段，每段0.1 coalescent time units
- 0.2*10  = 10个时间段，每段0.2 coalescent time units
- 0.5*5   = 5个时间段，每段0.5 coalescent time units
- 1*5     = 5个时间段，每段1.0 coalescent time units
- 2*5     = 5个时间段，每段2.0 coalescent time units

总时间段数 = 15+10+5+5+5 = 40
```

- 时间分辨率越高(数字越小)，分析越精细，但计算时间越长
- 官方建议: 30-40段用于正式分析，测试可用较少

### 3. 群体列表配置

```bash
# 在 config.sh 中定义
ALL_POPS="Jino,Tibetan,Qiang,Sherpa,Hani,Lahu,Pumi,Mosuo,Naxi,Wa,Deang,Dai,Zhuang,Dong,Buyei,Han"

# 跨群体分析配对
CROSS_PAIRS=(
    "Jino:Tibetan"
    "Jino:Han"
    "Jino:Dai"
    "Tibetan:Han"
)
```

### 4. 断点续传控制

```bash
# 在 config.sh 中
RESUME_MODE=1  # 1=启用断点续传, 0=禁用

# 运行特定步骤
RUN_SAMPLE_SELECTION=1
RUN_EXTRACT_VCF=1
RUN_GENERATE_INPUT=1
RUN_MSMC_SINGLE=1
RUN_MSMC_CROSS=1
RUN_VISUALIZATION=1
```

---

## B. 各步骤输出目录结构与结果示例

### Step 1: 样本选择 → `01_select_samples.sh`

**输出目录**: `sample_lists/`

```
sample_lists/
├── Jino.txt
├── Tibetan.txt
├── Han.txt
├── Dai.txt
├── Hani.txt
├── Lahu.txt
├── Pumi.txt
├── Mosuo.txt
├── Naxi.txt
├── Wa.txt
├── Deang.txt
├── Zhuang.txt
├── Dong.txt
├── Buyei.txt
├── Qiang.txt
├── Sherpa.txt
└── all_samples.txt
```

**Jino.txt 示例**:
```
AAGC032011D
AAGC032297D
```

**all_samples.txt 示例**:
```
AAGC032011D	Jino
AAGC032297D	Jino
AAGC022051D	Tibetan
...
```

---

### Step 2: 提取单样本VCF → `02_extract_single_vcf.sh`

**输出目录**: `single_vcf/`

```
single_vcf/
├── Jino_AAGC032011D_chr1.vcf.gz
├── Jino_AAGC032011D_chr1.vcf.gz.tbi
├── Jino_AAGC032011D_chr2.vcf.gz
├── Jino_AAGC032011D_chr2.vcf.gz.tbi
...
├── Jino_AAGC032011D_chr22.vcf.gz
├── Jino_AAGC032297D_chr1.vcf.gz
...
└── Tibetan_AAGC022051D_chr1.vcf.gz
```

**文件说明**:
- 格式: `{population}_{sample_id}_chr{chromosome}.vcf.gz`
- 包含: 该样本该染色体的所有位点 (包括hom-ref)
- 索引: `.tbi` 文件

---

### Step 2b: 处理VCF → `02b_process_vcf.sh`

**输出目录**: `single_vcf/` (继续使用)

```
single_vcf/
├── Jino_AAGC032011D_chr1.vcf.gz              # 原始 (Step 2)
├── Jino_AAGC032011D_chr1.variant.vcf.gz      # 处理后: 仅变异位点
├── Jino_AAGC032011D_chr1.mask.bed.gz        # 处理后: callable regions mask
├── Jino_AAGC032011D_chr1.variant.vcf.gz.tbi
...
```

**生成的文件**:

| 文件类型 | 格式 | 说明 |
|----------|------|------|
| `*.variant.vcf.gz` | VCF | 只包含变异位点 (segregating sites) |
| `*.mask.bed.gz` | BED | 该样本被成功call到的区域 |

---

### Step 3: 生成MSMC输入 → `03_generate_msmc_input.sh`

**输出目录**: `msmc_input/`

```
msmc_input/
├── Jino_chr1.msmc
├── Jino_chr2.msmc
...
├── Jino_chr22.msmc
├── Tibetan_chr1.msmc
├── Tibetan_chr2.msmc
...
├── Han_chr1.msmc
...
└── Dai_chr1.msmc
```

**MSMC输入文件格式** (4列tab分隔):
```
1	58432	63	TCCC
1	58448	16	GAAA
1	68306	15	CTTT
...
```
列: `染色体	位置	距上次变异位点的call数	单倍型`

---

### Step 4: 运行MSMC (单群体) → `04_run_msmc.sh`

**输出目录**: `msmc_output/`

```
msmc_output/
├── Jino_chr1.msmc2
├── Jino_chr1.msmc2.log
├── Jino_chr2.msmc2
├── Jino_chr2.msmc2.log
...
├── Jino_final.msmc2              # 合并后的最终结果
├── Tibetan_chr1.msmc2
...
└── Han_chr1.msmc2
```

**输出文件说明**:

| 文件 | 说明 |
|------|------|
| `*.msmc2` | 最终参数估计 (主要结果) |
| `*.msmc2.log` | 运行日志 |
| `*_final.msmc2` | 多染色体合并结果 |

**msmc2 文件内容示例**:
```
time_index	left_time_boundary	right_time_boundary	lambda_00
0	-0	2.09028e-06	1086.3
1	2.09028e-06	4.23486e-06	3373.81
2	4.23486e-06	6.43663e-06	3726.96
...
```
列: `时间索引	左边界	右边界	lambda(溯祖率)`

---

### Step 5: 运行MSMC (跨群体) → `05_run_msmc_cross.sh`

**输出目录**: `msmc_output/` (继续使用)

```
msmc_output/
├── cross_Jino_Tibetan_chr1.msmc2
├── cross_Jino_Tibetan_chr2.msmc2
...
├── cross_Jino_Han_chr1.msmc2
├── cross_Jino_Dai_chr1.msmc2
...
└── cross_Tibetan_Han_chr1.msmc2
```

**跨群体输出格式** (包含lambda_00, lambda_01, lambda_11):
```
time_index	left_time_boundary	right_time_boundary	lambda_00	lambda_01	lambda_11
0	-0	2.79218e-06	2605.47	71.9887	4206.61
1	2.79218e-06	5.68236e-06	6451.92	1256.07	3897.26
...
```
- lambda_00: 群体1内部溯祖率
- lambda_01: 群体间溯祖率 (交叉coalescence)
- lambda_11: 群体2内部溯祖率

---

### Step 6: 可视化 → `plot_msmc_ne.py` + `plot_msmc_cross.py`

**输出目录**: `visualization/`

```
visualization/
├── Ne_curves.png              # 多人群Ne历史曲线
├── Ne_curves.pdf             # 矢量格式 (出版用)
├── Ne_ratio.png               # 相对于参考人群的Ne比例
├── Ne_ratio.pdf
├── Cross_coalescence.png      # 跨群体coalescence率
├── Cross_coalescence.pdf
├── Cross_coalescence_relative.png  # 归一化交叉率
└── Split_time_heatmap.png     # 群体分化时间热图
```

**可视化图表说明**:

| 文件 | 内容 |
|------|------|
| Ne_curves | X轴: 时间(百万年), Y轴: 有效群体大小(对数) |
| Ne_ratio | 各人群Ne相对于参考人群(如Han)的比例 |
| Cross_coalescence | 跨群体溯祖率随时间变化 |
| Split_time_heatmap | 群体分化时间矩阵热图 |

---

### 完整目录结构示例

```
true_msmc/
├── config.sh
├── run_pipeline.sh
├── 01_select_samples.sh
├── 02_extract_single_vcf.sh
├── 02b_process_vcf.sh
├── 03_generate_msmc_input.sh
├── 04_run_msmc.sh
├── 05_run_msmc_cross.sh
├── plot_msmc_ne.py
├── plot_msmc_cross.py
│
├── .step_01_samples_done
├── .step_02_vcf_done
├── .step_02b_process_done
├── .step_03_input_done
├── .step_04_msmc_single_done
├── .step_05_msmc_cross_done
├── .step_06_visualization_done
│
├── sample_lists/              # ~50 files
│
├── single_vcf/                # ~2000+ files (16 pops × 2 samples × 22 chr)
│
├── msmc_input/                # ~352 files (16 pops × 22 chr)
│
├── msmc_output/               # ~400+ files
│
├── visualization/             # ~8 files
│
└── logs/
```

---

## 目录结构

```
true_msmc/
├── config.sh                 # 配置文件
├── run_pipeline.sh          # 主运行脚本
│
├── 01_select_samples.sh     # 样本选择
├── 02_extract_single_vcf.sh # 提取单样本VCF
├── 02b_process_vcf.sh      # 处理VCF (variant + mask)
├── 03_generate_msmc_input.sh # 生成MSMC输入
├── 04_run_msmc.sh           # 运行单群体MSMC
├── 05_run_msmc_cross.sh     # 运行跨群体MSMC
│
├── plot_msmc_ne.py          # Ne曲线可视化
├── plot_msmc_cross.py       # 跨群体 coalescence 可视化
│
├── sample_lists/            # 样本列表
├── single_vcf/              # 单样本VCF文件
├── msmc_input/              # MSMC输入文件
├── msmc_output/              # MSMC输出结果
├── visualization/            # 可视化图表
└── logs/                    # 日志文件
```

---

## 依赖软件

- **MSMC2**: 群体历史分析
- **bcftools**: VCF文件处理
- **Python 3**: 
  - matplotlib
  - numpy
  - generate_multihetsep.py
  - vcfAllSiteParser.py
- **tabix**: VCF索引
- **msmc-tools**: 官方工具包

---

## 注意事项

1. **VCF必须Phased** - 必须有GT字段 (使用|分隔)
2. **Mappability Mask** - 需要按染色体分开 (chr1.bed.gz, chr2.bed.gz...)
3. **样本数量** - MSMC至少需要2个样本，建议4个以上
4. **断点续传** - 设置 `RESUME_MODE=1` 可从中断处继续

---

## 参考

- MSMC GitHub: https://github.com/stschiff/msmc
- MSMC-tools: https://github.com/stschiff/msmc-tools
- 原始论文: Schiffels & Durbin (2014), Nature
