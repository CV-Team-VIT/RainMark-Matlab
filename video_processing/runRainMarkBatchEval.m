%% runRainMarkBatchEval.m
% Batch evaluation of RainMark metrics for all rainy frames in Rain_Data.
%
% For each rainy frame this script:
%   1. Resolves its corresponding GT image using the naming convention:
%        rainy/<prefix>_<suffix>.<ext>  →  groundtruth/<prefix>.<ext>
%        rainy/<name>.<ext>             →  groundtruth/<name>.<ext>   (no underscore)
%   2. Runs detect_rainstreaks() to obtain RainMark scores.
%   3. Measures wall-clock execution time (seconds).
%   4. Estimates GFLOPs based on image dimensions and algorithm structure.
%   5. Writes one row per frame to a CSV file saved in Rain_Data/rainy/.
%
% Output CSV columns:
%   frame_name, gt_name, width, height, time_sec, gflops,
%   e1, ns1, streak_area, percentage_streak_area, psnr_db, ssim
%
% GT matching rule
%   Given a rainy filename stem (everything before the extension):
%     - Split on the FIRST underscore → take the left part as gt_stem
%     - Search Rain_Data/groundtruth/ for a file named gt_stem.<any ext>
%     - If not found, skip the frame with a warning.
%
% Usage: Run from any directory; the script auto-locates itself.
% -------------------------------------------------------------------------

clc;
close all;

%% ── Paths ──────────────────────────────────────────────────────────────
script_dir   = fileparts(mfilename('fullpath'));
project_root = fullfile(script_dir, '..');

rainy_dir = fullfile(project_root, 'Rain_Data', 'rainy');
gt_dir    = fullfile(project_root, 'Rain_Data', 'groundtruth');
csv_out   = fullfile(rainy_dir, 'rainmark_results.csv');

%% ── Add core functions to path ──────────────────────────────────────────
addpath(fullfile(project_root, 'core'));
addpath(fullfile(project_root, 'metrics'));

%% ── RainMark hyper-parameters (same as demo) ───────────────────────────
S                  = 7;    % subwindow size
visibilityPercent  = 5;    % Weber contrast threshold (%)
brightThresh       = 150;  % saturation brightness threshold

%% ── Enumerate rainy frames ──────────────────────────────────────────────
rainy_files = [dir(fullfile(rainy_dir, '*.jpg')); ...
    dir(fullfile(rainy_dir, '*.png'))];
rainy_files = sort_struct_by_name(rainy_files);   % deterministic order
nFrames = numel(rainy_files);
fprintf('Found %d rainy frames in Rain_Data/rainy/.\n\n', nFrames);

%% ── Pre-load GT index (filename stem → full path) ──────────────────────
gt_all = [dir(fullfile(gt_dir, '*.jpg')); ...
    dir(fullfile(gt_dir, '*.png'))];
gt_index = struct();    % maps gt_stem → full file path
for k = 1:numel(gt_all)
    [~, stem, ~] = fileparts(gt_all(k).name);
    gt_index.(matlab.lang.makeValidName(stem)) = fullfile(gt_dir, gt_all(k).name);
end
fprintf('Indexed %d GT images in Rain_Data/groundtruth/.\n\n', numel(gt_all));

%% ── GFLOP estimation note ───────────────────────────────────────────────
% The dominant cost in detect_rainstreaks is the triple-nested sliding-window
% contrast computation in functionContrastAt5PerCentRain (and GT variant).
%   numWindows   = ceil(H / (S/2)) * ceil(W / (S/2))
%   opsPerWindow = S^2 * 255 * ~6   (comparisons + divides in inner loops)
%   morphOps     = 8 angles × 2 (erode/dilate) × H*W * linLen  (approx)
%   totalFlops   = 2 * (numWindows*opsPerWindow + morphOps)   [Rain + GT]
%   GFLOPs       = totalFlops / 1e9
% -------------------------------------------------------------------------

%% ── Open CSV for writing ────────────────────────────────────────────────
fid = fopen(csv_out, 'w');
if fid == -1
    error('Cannot open CSV for writing: %s', csv_out);
end
fprintf(fid, 'frame_name,gt_name,width,height,time_sec,gflops,e1,ns1,streak_area,percentage_streak_area,psnr_db,ssim\n');

%% ── Main loop ───────────────────────────────────────────────────────────
skipped = 0;

for i = 1:nFrames
    fname = rainy_files(i).name;
    fpath = fullfile(rainy_dir, fname);

    % ── Resolve GT for this rainy frame ──────────────────────────────────
    [~, stem_full, ~] = fileparts(fname);

    % Split on first underscore to get the GT stem
    us_idx = strfind(stem_full, '_');
    if ~isempty(us_idx)
        gt_stem = stem_full(1 : us_idx(1)-1);   % e.g. "3" from "3_14"
    else
        gt_stem = stem_full;                      % e.g. "613" from "613"
    end

    % Look up in GT index
    valid_key = matlab.lang.makeValidName(gt_stem);
    if ~isfield(gt_index, valid_key)
        fprintf('[%3d/%d] SKIP  %s  (no GT found for stem "%s")\n', ...
            i, nFrames, fname, gt_stem);
        skipped = skipped + 1;
        continue;
    end
    gt_path = gt_index.(valid_key);
    [~, gt_name_only, gt_ext] = fileparts(gt_path);
    gt_filename = [gt_name_only, gt_ext];

    fprintf('[%3d/%d] Processing: %-20s  →  GT: %s\n', i, nFrames, fname, gt_filename);

    % ── Load images ──────────────────────────────────────────────────────
    Rain = imread(fpath);
    GT   = imread(gt_path);
    [H, W, ~] = size(Rain);

    % ── Run RainMark (figures suppressed) ────────────────────────────────
    tic;
    try
        results = detect_rainstreaks_silent(GT, Rain, S, visibilityPercent, brightThresh);
    catch ME
        fprintf('  ERROR on frame %s: %s\n', fname, ME.message);
        fprintf(fid, '%s,%s,%d,%d,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN\n', ...
            fname, gt_filename, W, H);
        close all;
        continue;
    end
    elapsed = toc;

    close all;  % close any figures opened by core functions

    % ── GFLOPs estimate ──────────────────────────────────────────────────
    step         = round(S / 2);
    numWindows_H = ceil(H / step);
    numWindows_W = ceil(W / step);
    numWindows   = numWindows_H * numWindows_W;

    flops_per_window = S^2 * 255 * 6;   % Weber contrast inner loops
    num_angles       = 8;
    linLen           = 3;
    flops_morph      = num_angles * 2 * H * W * linLen;  % erode+dilate per image

    total_flops = 2 * (numWindows * flops_per_window + flops_morph);
    gflops      = total_flops / 1e9;

    % ── PSNR & SSIM (rainy vs GT) ─────────────────────────────────────
    GT_resized = imresize(GT, [H W]);   % match frame dims if GT size differs
    [psnr_val, ~] = psnr(Rain, GT_resized);
    [ssim_val, ~] = ssim(Rain, GT_resized);

    % ── Write CSV row ─────────────────────────────────────────────────
    fprintf(fid, '%s,%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
        fname, gt_filename, W, H, elapsed, gflops, ...
        results.e1, results.ns1, results.streak_area, results.percentage_streak_area, ...
        psnr_val, ssim_val);

    fprintf('  Time: %.3f s | GFLOPs: %.4f | e1: %.4f | ns1: %.4f | streak%%: %.4f | PSNR: %.2f dB | SSIM: %.4f\n', ...
        elapsed, gflops, results.e1, results.ns1, results.percentage_streak_area, psnr_val, ssim_val);
end

%% ── Finalise ─────────────────────────────────────────────────────────────
fclose(fid);
fprintf('\nDone! Processed %d frames, skipped %d (no GT).\n', nFrames - skipped, skipped);
fprintf('Results saved to:\n  %s\n', csv_out);

%% =========================================================================
%% LOCAL HELPER: detect_rainstreaks_silent
%% Wraps detect_rainstreaks, suppressing figure/waitbar output.
%% =========================================================================
function results = detect_rainstreaks_silent(GT, Rain, S, visibilityPercent, brightThresh)
old_vis = get(0, 'DefaultFigureVisible');
set(0, 'DefaultFigureVisible', 'off');
try
    results = detect_rainstreaks(GT, Rain, S, visibilityPercent, brightThresh);
catch ME
    set(0, 'DefaultFigureVisible', old_vis);
    rethrow(ME);
end
set(0, 'DefaultFigureVisible', old_vis);
end

%% =========================================================================
%% LOCAL HELPER: sort_struct_by_name
%% Sorts a struct array (from dir()) alphabetically by .name field.
%% =========================================================================
function s = sort_struct_by_name(s)
[~, idx] = sort({s.name});
s = s(idx);
end
