% run_rainmark_single_image.m
clc; clear; close all;

% --- PATHS SECTION ---
video_folder = '/Users/debayan/Documents/CV Team/RainMark-Matlab/failure/video1';
rain_image_path = fullfile(video_folder, 'frames', 'frame_000001.png'); % Example input
gt_image_path = fullfile(video_folder, 'gt', 'gt_000001.png'); % Example input
output_rainmark_folder = fullfile(video_folder, 'rainmarked');
% ---------------------

% Add required paths for RainMark functions
% Assuming this script is located in the `failure` directory
this_dir = fileparts(mfilename('fullpath'));
project_root = fullfile(this_dir, '..');
addpath(fullfile(project_root, 'core'));
addpath(fullfile(project_root, 'metrics'));

if ~exist(output_rainmark_folder, 'dir')
    mkdir(output_rainmark_folder);
end

% Read images
fprintf('Loading images...\n');
try
    Rain = imread(rain_image_path);
    GT = imread(gt_image_path);
catch ME
    error('Could not load input images. Please check the paths section. Error: %s', ME.message);
end

% Setup parameters for rain streak detector
S = 7;                    % Subwindow size
visibilityPercent = 5;     % 5% contrast threshold
brightThresh = 150;        % Pixel brightness threshold

% Detect rain streaks
fprintf('Running RainMark...\n');
results = detectRainStreaks(GT, Rain, S, visibilityPercent, brightThresh);

% Save highlighted rain image
[~, name, ext] = fileparts(rain_image_path);
overlay_path = fullfile(output_rainmark_folder, [name '_highlighted' ext]);
imwrite(results.overlay, overlay_path);

% Compute generic metrics if formulas match size
try
    [PSNR, ~] = computePSNR(GT, Rain);
    [SSIM, ~] = computeSSIM(GT, Rain);
catch
    PSNR = NaN;
    SSIM = NaN;
end

% Display metrics
fprintf('\n--- RainMark Metrics ---\n');
fprintf('Edge Amplification (e1): %.3f\n', results.e1);
fprintf('Newly Saturated Pixels (ns1): %.2f%%\n', results.ns1);
fprintf('Rain Streak Coverage: %.2f%%\n', (results.percentage_streak_area/100));
fprintf('PSNR: %.2f dB\n', PSNR);
fprintf('SSIM: %.4f\n', SSIM);
fprintf('------------------------\n');
fprintf('Saved highlighted rain image to: %s\n', overlay_path);
