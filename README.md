# RainMark — Rain Streak Detection & Analysis Toolkit

**RainMark** is a MATLAB-based framework for detecting, quantifying, and visualizing rain streaks in outdoor images. It compares a degraded (rainy) image against its ground-truth (clean) counterpart using a multi-stage pipeline that combines orientation analysis, morphological contrast estimation, and adaptive mask refinement.

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Algorithm Description](#algorithm-description)
3. [Folder Structure](#folder-structure)
4. [Function Reference](#function-reference)
5. [Getting Started](#getting-started)
6. [Running the Demos](#running-the-demos)
7. [Dataset Information](#dataset-information)
8. [Notes and Known Issues](#notes-and-known-issues)
9. [References](#references)

---

## Project Overview

Rain streaks introduce spurious edges, brightness spikes, and local contrast distortions into outdoor images. RainMark estimates three physically motivated metrics from a rainy/GT image pair:

| Metric | Symbol | Meaning |
|--------|--------|---------|
| Edge Amplification Ratio | `e1` | Excess of visually contrasting edges in the rainy image vs. the clean image |
| Newly Saturated Pixels | `ns1` | Fraction of pixels that become bright-saturated only in the rainy image |
| Rain Streak Coverage | `percentage_streak_area` | Percentage of image area occupied by confirmed rain-streak pixels |

The output also includes a **neon-highlighted overlay image** that visually marks detected streak pixels on the original rainy frame.

---

## Algorithm Description

```
Rainy Image (I)  ──┐
                   ├──► [1] Gradient Analysis + Orientation Histogram
Clean Image (J)  ──┘         └─► findAdaptiveOrientationROI.m
                                        │
                                        ▼
                         [2] Directional Contrast Estimation
                          ├─► computeContrastMapRain.m  →  Mask_Rain, angles
                          └─► computeContrastMapGT.m    →  Mask_GT
                                        │
                                        ▼
                         [3] Metric Computation
                          ├─► Edge Amplification  (e1)
                          ├─► Newly Saturated Pixels  (ns1)
                          └─► Adaptive Brightness Delta (δ)
                                        │
                                        ▼
                         [4] Rain Streak Mask
                              Mask_Rain ∩ ¬Mask_GT ∩ ΔBrightness > δ
                                        │
                                        ▼
                         [5] Mask Cleanup
                              cleanRainMask.m  (blob-size adaptive filtering)
                                        │
                                        ▼
                         [6] Output: e1, ns1, streak coverage %, overlay image
```

### Step-by-step

1. **Gradient Analysis** (`computeContrastMapRain.m`)  
   Computes Sobel gradients on the grayscale rainy image. Builds an orientation histogram over strong-gradient pixels, then extracts dominant edge orientations and adaptive angular ROIs via `findAdaptiveOrientationROI.m`.

2. **Orientation-Aware Contrast Map — Rain** (`computeContrastMapRain.m`)  
   Uses directional morphological erosion/dilation (line structuring elements) along the 8 sampled orientations derived from Step 1. Applies Weber contrast in sliding subwindows to build a binary mask (`Mask_Rain`) of visually significant edges.

3. **Orientation-Aware Contrast Map — GT** (`computeContrastMapGT.m`)  
   Repeats the same contrast computation on a Gaussian-smoothed GT image, using the **same 8 orientation angles** transferred from the rainy computation. This ensures the comparison is directionally coherent.

4. **Metric Computation** (`detectRainStreaks.m`)  
   - `e1 = max(0, W_I - W_J) / max(W_I, W_J)` — edge amplification  
   - `ns1` — fraction of pixels bright-saturated in I but not in J  
   - `δ` — 80th-percentile normalized brightness delta over local neighborhood

5. **Rain Streak Mask**  
   A pixel is flagged as a rain streak if it is a contrast edge in the rainy image (`Mask_Rain = 1`), not a natural edge in the clean image (`Mask_GT = 0`), and its brightness difference exceeds the adaptive threshold `δ`.

6. **Mask Cleanup** (`cleanRainMask.m`)  
   Removes small spurious blobs. The size cutoff is adaptive: `1.5 × median(blob areas)`, with a minimum floor of 10 pixels.

---

## Folder Structure

```
RainMark/
│
├── core/                            # Core algorithm functions
│   ├── detectRainStreaks.m          # Main detection pipeline (entry point)
│   ├── computeContrastMapRain.m     # Weber contrast analysis for rainy image
│   ├── computeContrastMapGT.m       # Weber contrast analysis for GT image
│   ├── findAdaptiveOrientationROI.m # Dominant orientation & adaptive ROI extraction
│   └── cleanRainMask.m             # Adaptive blob-size cleanup of rain mask
│
├── metrics/                         # Image quality metric utilities
│   ├── computePSNR.m                # Peak Signal-to-Noise Ratio
│   └── computeSSIM.m                # Structural Similarity Index
│
├── demos/                           # Runnable demo and evaluation scripts
│   ├── runRainDetectionDemo.m       # Demo: detect rain streaks and display overlay
│   └── runMetricsEvaluation.m      # Demo: compute PSNR and SSIM for an image pair
│
├── data/
│   ├── sample_images/               # Curated sample image pairs for testing
│   │   ├── SF1/                     # Scene family 1 (real outdoor scene)
│   │   ├── SF2/                     # Scene family 2
│   │   ├── SF3/                     # Scene family 3 (used by default in demos)
│   │   ├── SF4/                     # Scene family 4
│   │   ├── SF5/                     # Scene family 5
│   │   ├── SF6/                     # Scene family 6
│   │   └── reference_pdfs/          # Research reference PDFs
│   │       ├── CVIU_framework.pdf   # Framework paper
│   │       ├── PSNR_curve.pdf       # PSNR analysis plots
│   │       ├── beta_dis.pdf         # Beta distribution analysis
│   │       └── sigma_curve.pdf     # Sigma curve plots
│   │
│   └── rain100h/                    # Rain100H benchmark dataset subset
│       ├── rainy/                   # Rainy input images (e.g., 15_14.jpg)
│       └── groundtruth/             # Corresponding clean ground-truth images
│
└── results/                         # Pre-computed output visualizations
    ├── highlighted_row1/            # Overlay results — row 1
    ├── highlighted_row2/            # Overlay results — row 2
    ├── highlighted_row3/            # Overlay results — row 3
    └── highlighted_row4/            # Overlay results — row 4
```

---

## Function Reference

### `core/detectRainStreaks.m`
**Main entry point** for the RainMark pipeline.

```matlab
results = detectRainStreaks(GT, Rain, S, visibilityPercent, brightThresh)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `GT` | uint8 RGB | Ground-truth clean image |
| `Rain` | uint8 RGB | Rainy input image |
| `S` | int | Subwindow size for local contrast (default: 7) |
| `visibilityPercent` | float | Weber contrast threshold in percent (default: 5) |
| `brightThresh` | int | Brightness saturation threshold 0–255 (default: 150) |

**Returns** a struct with fields:

| Field | Description |
|-------|-------------|
| `results.e1` | Edge amplification ratio ∈ [0, 1] |
| `results.ns1` | Newly saturated pixel fraction ∈ [0, 1] |
| `results.streak_area` | Streak area as a fraction of total pixels |
| `results.percentage_streak_area` | Streak area percentage (0–100) |
| `results.overlay` | uint8 RGB image with rain streaks highlighted in neon green (RGB: 57, 255, 20) |

---

### `core/computeContrastMapRain.m`
Computes orientation-aware Weber contrast mask for the **rainy** image.

```matlab
[Mask, Crr, dominantAnglePrimary, dominantAngleWeighted, ROI, angles] = ...
    computeContrastMapRain(I1, S, percentage)
```

Also performs gradient orientation analysis and delegates to `findAdaptiveOrientationROI` to determine dominant streak directions. Returns `angles` — an 8-element vector of sampled directions shared with the GT computation.

---

### `core/computeContrastMapGT.m`
Computes orientation-aware Weber contrast mask for the **GT (clean)** image, using the same orientation angles from the rainy analysis to ensure directional consistency.

```matlab
[Mask, Crr] = computeContrastMapGT(I1, S, percentage, angles)
```

> **Note:** The `angles` argument is mandatory and must come from `computeContrastMapRain`.

---

### `core/findAdaptiveOrientationROI.m`
Extracts dominant orientation peaks from an edge-direction histogram and builds adaptive angular ROIs. Handles the 0°/180° circular wrap-around correctly.

```matlab
[dominantAnglePrimary, dominantAngleWeighted, ROI, isNearZeroOr180, peakAngles] = ...
    findAdaptiveOrientationROI(BinCenters, Counts, tolerance)
```

| Output | Description |
|--------|-------------|
| `dominantAnglePrimary` | Strongest orientation peak (degrees) |
| `dominantAngleWeighted` | Weighted-mean orientation across all strong peaks |
| `ROI` | N×2 matrix of merged angular intervals [start, end] (degrees) |
| `isNearZeroOr180` | Boolean flag — true if dominant direction is near-vertical |
| `peakAngles` | Vector of all detected significant orientation peaks |

---

### `core/cleanRainMask.m`
Removes small spurious blobs from the binary rain-streak mask using an adaptive median-based area cutoff.

```matlab
mask_clean = cleanRainMask(mask)
```

Cutoff = `max(10, round(1.5 × median(blob areas)))`.

---

### `metrics/computePSNR.m`
Computes Peak Signal-to-Noise Ratio between two images.

```matlab
[peaksnr, snr] = computePSNR(A, ref)
[peaksnr, snr] = computePSNR(A, ref, peakval)
```

Supports `uint8`, `uint16`, `int16`, `single`, `double`. Copyright 2013–2015 MathWorks, Inc.

---

### `metrics/computeSSIM.m`
Computes Structural Similarity Index (SSIM) between two images (Wang et al., 2004).

```matlab
ssimval = computeSSIM(A, ref)
[ssimval, ssimmap] = computeSSIM(A, ref)
[ssimval, ssimmap] = computeSSIM(A, ref, 'DynamicRange', L, ...)
```

Named parameters: `DynamicRange`, `RegularizationConstants`, `Exponents`, `Radius`.  
Copyright 2013–2014 MathWorks, Inc.

---

## Getting Started

### Requirements
- MATLAB R2019b or later
- Image Processing Toolbox (required for `imgaussfilt`, `bwconncomp`, `regionprops`, `imerode`, `imdilate`, `strel`, `imboxfilt`, `imgradientxy`)

### Setup

```matlab
% From MATLAB, navigate to the project root and add all subfolders to path:
cd('/path/to/RainMark')
addpath(genpath('.'))
```

### Quick Example

```matlab
GT   = imread('data/sample_images/SF3/GT_303.png');
Rain = imread('data/sample_images/SF3/2.png');

S                = 7;    % subwindow size
visibilityPercent = 5;   % 5% Weber contrast threshold
brightThresh     = 150;  % saturation threshold

results = detectRainStreaks(GT, Rain, S, visibilityPercent, brightThresh);

fprintf('Edge Amplification (e1):       %.4f\n', results.e1);
fprintf('Newly Saturated Pixels (ns1):  %.4f\n', results.ns1);
fprintf('Rain Streak Coverage:          %.2f%%\n', results.percentage_streak_area);

figure, imshow(results.overlay);
title('Detected Rain Streaks (Neon Overlay)');
```

---

## Running the Demos

### Rain Detection Demo
```matlab
cd demos
runRainDetectionDemo
```
Loads `data/sample_images/SF3/2.png` (rainy) and `data/sample_images/SF3/GT_303.png` (GT), runs `detectRainStreaks`, and displays the streak overlay alongside metric printouts.

### Metrics Evaluation Demo
```matlab
cd demos
runMetricsEvaluation
```
Loads two images from `data/sample_images/SF3/` and computes PSNR and SSIM scores.

> [!IMPORTANT]
> The demo scripts (`runRainDetectionDemo.m` and `runMetricsEvaluation.m`) contain hardcoded relative paths (e.g., `'Sample/SF3/2.png'`) that **reflect the original folder structure**. After the reorganization, update these paths to `'../data/sample_images/SF3/2.png'` or run them from the project root with `addpath(genpath('.'))` and update paths accordingly.

---

## Dataset Information

### Sample Image Families (SF1–SF6)
Six custom scene families located in `data/sample_images/`. Each contains:
- Rainy input images (numeric filenames, e.g., `1.png`, `2.png`)
- Ground-truth clean images (prefixed `GT_`, e.g., `GT_303.png`)
- Some families contain additional derained outputs (e.g., `lhpA1.png`, `lhpB2.png`) for comparison
- SF2 also includes a `rr1k/` subfolder with additional result variants

### Rain100H Benchmark
The `data/rain100h/` folder holds a subset of the **Rain100H** benchmark dataset (Heavy Rain, 100 pairs). Originally from:
> Yang, W., Tan, R.T., Feng, J., Liu, J., Guo, Z., Yan, S. (2017). *Deep Joint Rain Detection and Removal from a Single Image.* CVPR 2017.

### Results — Highlighted Image Rows
`results/highlighted_row1/` through `highlighted_row4/` contain pre-computed neon-overlay output images organized in rows for a visual comparison table (likely for a paper or report figure).

---

## Notes and Known Issues

- **`computePSNR.m` / `computeSSIM.m`**: These are local copies of MATLAB's built-in `psnr` and `ssim` functions included here to ensure compatibility in environments where the Image Processing Toolbox version differs. They **shadow** the built-ins when on the MATLAB path — remove from path if you prefer the built-in versions.

- **`findAdaptiveOrientationROI.asv`**: This is a MATLAB **auto-save file** generated by the MATLAB editor. It is an older backup of `findAdaptiveOrientationROI.m` and can be safely ignored or deleted.

- **Progress bars**: `computeContrastMapRain.m` and `computeContrastMapGT.m` display `waitbar` progress dialogs during the sliding-window contrast computation. On large images this step can be slow (~minutes); the subwindow stride (`round(S/2)`) provides a speed/accuracy trade-off.

- **Debug print statements**: `detectRainStreaks.m` contains several `disp` and `fprintf` debug statements (e.g., `disp('Angles before GT call:')`) and intermediate `figure` calls that display intermediate masks. These are intentional for development and can be commented out for production use.

---

## References

1. **RainMark Framework**: Internal framework paper — see `data/sample_images/reference_pdfs/CVIU_framework.pdf`

2. **SSIM**: Wang, Z., Bovik, A. C., Sheikh, H. R., & Simoncelli, E. P. (2004). *Image Quality Assessment: From Error Visibility to Structural Similarity.* IEEE Transactions on Image Processing, 13(4), 600–612.

3. **Rain100H Dataset**: Yang, W., et al. (2017). *Deep Joint Rain Detection and Removal from a Single Image.* CVPR 2017.

4. **Weber Contrast**: Based on local luminance contrast defined as `|I - I_background| / I_background`, thresholded at the specified `visibilityPercent`.
# RainMark-Matlab
