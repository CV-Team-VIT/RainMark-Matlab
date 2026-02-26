close all
clear all
clc
% read the GT
% ImagePath1 = 'sots_compliation/OurN_OTS_Result/our1_0060.png';
ImagePath1 = 'Sample/SF3/1.png';
input = imread(ImagePath1);
figure, imshow(input);
% Ref = double(input)./255;
% read the restored image
% ImagePath2 = 'SPRINGER/outdoor/No_weights/8_dc.jpg';
ImagePath2 = 'Sample/SF3/GT_152.png';
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