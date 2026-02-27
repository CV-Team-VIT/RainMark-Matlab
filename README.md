# RainMark-Matlab

A MATLAB toolkit for rain streak detection and image quality evaluation.

---

## Requirements

- MATLAB R2019b or later
- Image Processing Toolbox

---

## Setup

Open MATLAB, navigate to the project root, and add all subfolders to the path:

```matlab
cd('/path/to/RainMark-Matlab')
addpath(genpath('.'))
```

---

## Running the Rain Detection Demo

```matlab
cd demos
runRainDetectionDemo
```

This loads a rainy image and its ground-truth counterpart from `data/sample_images/SF3/`, runs the rain streak detector, prints the metrics to the console, and displays the result as a neon-highlighted overlay image.

**Console output includes:**
- Edge Amplification (`e1`)
- Newly Saturated Pixels (`ns1`)
- Rain Streak Coverage (%)

---

## Running the Metrics Evaluation

```matlab
cd demos
runMetricsEvaluation
```

This loads two images from `data/sample_images/SF3/` and computes **PSNR** and **SSIM** scores, printing the results to the console.

---

## Using the Detector Directly

```matlab
GT   = imread('data/sample_images/SF3/GT_303.png');
Rain = imread('data/sample_images/SF3/2.png');

results = detectRainStreaks(GT, Rain, 7, 5, 150);

fprintf('Edge Amplification (e1):      %.4f\n', results.e1);
fprintf('Newly Saturated Pixels (ns1): %.4f\n', results.ns1);
fprintf('Rain Streak Coverage:         %.2f%%\n', results.percentage_streak_area);

figure, imshow(results.overlay);
title('Detected Rain Streaks');
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `GT` | uint8 RGB | Ground-truth clean image |
| `Rain` | uint8 RGB | Rainy input image |
| `S` | int | Subwindow size (recommended: `7`) |
| `visibilityPercent` | float | Contrast visibility threshold in % (recommended: `5`) |
| `brightThresh` | int | Brightness saturation threshold 0–255 (recommended: `150`) |

---

## Notes

- The demo scripts contain hardcoded paths relative to their original location. If you run them from a different working directory, update the image paths inside the scripts accordingly.
- `computePSNR.m` and `computeSSIM.m` are local implementations and will shadow MATLAB's built-in `psnr` and `ssim` functions when on the path. Remove the `metrics/` folder from the path if you prefer the built-ins.
