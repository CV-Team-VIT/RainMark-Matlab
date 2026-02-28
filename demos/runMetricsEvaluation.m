close all
clear all
clc
% Auto-detect project root relative to this script
this_dir = fileparts(mfilename('fullpath'));
project_root = fullfile(this_dir, '..');

% read the GT
ImagePath1 = fullfile(project_root, 'data', 'sample_images', 'SF3', '1.png');
input = imread(ImagePath1);
figure, imshow(input);

% read the restored image
ImagePath2 = fullfile(project_root, 'data', 'sample_images', 'SF3', 'GT_152.png');
output = imread(ImagePath2);
figure, imshow(output);
% A = double(output)./255;
% CM = UICM(output);
% SM = UISM(output);
% CnM = UIConM(output);
% figure, imshow([input,output]), title('input/output image');
[peaksnr, snr] = psnr(output,input);
[ssimval, ssimmap] = ssim(output,input);
PSNR  = peaksnr
SSIM = ssimval

% [p_hvs_m, p_hvs] = psnrhvsm(output,input);
% [FSIM, FSIMc] = FeatureSIM(output,input);
% % PSNR  = peaksnr;
% % SSIM = ssimval;
% % PSNR-H = p_hvs_m;
% % FSIM = FSIM;
% [peaksnr,ssimval, p_hvs_m, FSIM]
% % density = FADE(output);
%% MSE
% err = MSE(output,input); % MSE(Reference_Image, Target_Image)
% fprintf('\n The mean-squared error is %0.4f\n', err);
% [PSNR,SSIM, err]
% Quality_measure = UIQM(output)