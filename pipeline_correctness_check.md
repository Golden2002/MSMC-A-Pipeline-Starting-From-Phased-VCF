# MSMC流程正确性检查报告 (更新版)

## 检查日期: 2025-03-11

基于GitHub官方指南 (`guide_from_github/`) 和用户实际情况 (VCF已Phased) 进行检查。

---

## ✅ 已修复的问题

### 问题1: VCF提取命令修复 ✅

**原问题**: 使用管道连接两个bcftools view命令

**修复后**:
```bash
# 正确: 一次命令同时指定样本和染色体
${BCFTOOLS} view \
    -s "${sample_id}" \
    -r "${chr}" \
    -Oz \
    -o "${output_vcf}" \
    "${PHASED_VCF}"
```

### 问题2: MSMC输入生成修复 ✅

**原问题**: 
1. 使用 `-o` 参数输出 (但该脚本不支持)
2. 每个样本单独处理再合并

**修复后**:
```bash
# 正确: 一次性传入所有样本VCF，输出到stdout
${PYTHON3} ${GENERATE_MULTIHETSEP} \
    --mask ${MAP_MASK} \
    sample1_chr1.vcf.gz \
    sample2_chr1.vcf.gz \
    > output.msmc
```

---

## 📋 正确的Workflow (从Phased VCF开始)

```
Step 1: 样本选择
    └── 从样本信息文件中按人群随机抽取n个样本
    └── 输出: sample_lists/{pop}.txt

Step 2: 提取单样本VCF
    └── 从Phased VCF中提取每个样本的VCF (按染色体)
    └── 命令: bcftools view -s sample -r chr -Oz -o out.vcf.gz in.vcf.gz
    └── 输出: single_vcf/{pop}_{sample}_chr*.vcf.gz

Step 3: 生成MSMC输入
    └── 使用generate_multihetsep.py处理每个群体的所有样本
    └── 命令: generate_multihetsep.py --mask mask.vcf.gz *.vcf.gz > output.msmc
    └── 输出: msmc_input/{pop}_chr*.msmc

Step 4: 运行MSMC (单群体)
    └── msmc2 --fixedRecombination -p pattern -t threads -o out input.msmc
    └── 输出: msmc_output/{pop}_chr*.msmc2

Step 5: 运行MSMC (跨群体)
    └── msmc2 --fixedRecombination -P 0,0,1,1 --skipAmbiguous -p pattern -o out input.msmc
    └── 输出: msmc_output/cross_{pop1}_{pop2}_chr*.msmc2

Step 6: 可视化
    └── Python脚本绘制Ne曲线和跨群体coalescence率
```

---

## 🔑 关键点总结

| 步骤 | 关键命令 | 注意事项 |
|------|----------|----------|
| VCF提取 | `bcftools view -s sample -r chr` | 样本名必须完全匹配 |
| 输入生成 | `generate_multihetsep.py ... > out.msmc` | **输出到stdout** |
| MSMC运行 | `msmc2 --fixedRecombination` | 需要≥2样本 |
| 跨群体 | `msmc2 -P 0,0,1,1 --skipAmbiguous` | -P指定群体模式 |

---

## 📝 配置文件要点 (已更新到config)

```bash
# =====================================
# MSMC 关键配置
# =====================================

# 输入VCF (已Phased)
PHASED_VCF="${PROJECT_ROOT}/107.IBD/data/NGS.phased.vcf.gz"

# Mask文件 (只需要mappability mask)
MAP_MASK="${MSMC_ROOT}/mappability_mask/GRCh38_nonunique_l250_m0_e0.bed"

# MSMC-tools脚本
GENERATE_MULTIHETSEP="${MSMC_TOOLS_DIR}/generate_multihetsep.py"

# 样本数量 (至少2个)
N_SAMPLES_PER_POP=2
```

---

## ✅ 流程状态

| 脚本 | 状态 | 说明 |
|------|------|------|
| 01_select_samples.sh | ✅ 正确 | 按人群随机抽取样本 |
| 02_extract_single_vcf.sh | ✅ 已修复 | 正确的bcftools命令 |
| 03_generate_msmc_input.sh | ✅ 已修复 | 正确的generate调用 |
| 04_run_msmc.sh | ✅ 正确 | MSMC2命令正确 |
| 05_run_msmc_cross.sh | ✅ 正确 | 跨群体参数正确 |
| plot_msmc_ne.py | ✅ 正确 | 解析逻辑正确 |
| plot_msmc_cross.py | ✅ 正确 | 解析逻辑正确 |

---

## 🚀 下一步建议

1. **测试运行**: 用一个小群体(如Jino, 2个样本, 1条染色体)测试完整流程
2. **验证输出**: 检查生成的.msmc文件格式是否正确
3. **调整参数**: 根据结果调整时间分段模式 `-p` 参数

