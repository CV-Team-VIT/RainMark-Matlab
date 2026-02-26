clc, clear all
close all

% Read images
% Rain = imread('Rain_Data/rainy/15_14.jpg'); % represented by I
% GT = imread('Rain_Data/groundtruth/15.jpg'); % represented by J
Rain = imread('Sample/SF3/2.png'); % represented by I
GT = imread('Sample/SF3/GT_303.png'); % represented by J
figure,imshow(Rain); 

%% Rain streak detector
% Analyze rain streaks
S = 7;                    % Subwindow size
visibilityPercent = 5;     % 5% contrast threshold
brightThresh = 150;        % Pixel brightness threshold

results = detect_rainstreaks(GT, Rain, S, visibilityPercent, brightThresh);

% Show overlay
figure, imshow(results.overlay);
title('Rain Streaks Highlighted (Neon)');


% Rain_Severity =17.138146 * results.e1 + 0.132285 * results.ns1 + 0.887244 * results.streak_area

% Display results
fprintf('Edge Amplification (e1): %.3f\n', results.e1);
fprintf('Newly Saturated Pixels (ns1): %.2f%%\n', results.ns1);
% fprintf('Rain Streak Area: %.2f\n', results.streak_area);
fprintf('Rain Streak Coverage: %.2f%%\n', results.percentage_streak_area/100);
