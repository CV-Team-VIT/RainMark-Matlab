function results = detect_rainstreaks(GT, Rain, S, visibilityPercent, brightThresh)

% Ensure all inputs are in double precision
% analyzeRainStreaks - Detect and quantify rain streaks in color images using contrast and saturation analysis.
%
% INPUTS:
%   GT                - Ground truth RGB image
%   Rain              - Rainy RGB image
%   S                 - Subwindow size for local contrast computation
%   visibilityPercent - Visibility threshold (e.g., 5 for 5%)
%   brightThresh      - Threshold for detecting saturated (bright) pixels
%
% OUTPUT:
%   results - struct with fields:
%       .e1                     - Edge amplification ratio
%       .ns1                    - Percentage of newly saturated pixels
%       .percentage_streak_area - Percentage of image area covered by rain streaks
%       .overlay                - RGB image with streaks highlighted in Neon

    %% 1. Compute gradient magnitude (on RGB → grayscale only for gradient)
    GT_gray   = double(rgb2gray(GT));
    Rain_gray = double(rgb2gray(Rain));

    %% 2. Contrast maps using RGB
    
%     [edges_GT] = functionContrastAt5PerCentRain(GT_gray, S, visibilityPercent);
[Mask_rain, ~, ~, ~, ~, angles] = functionContrastAt5PerCentRain(Rain_gray, S, visibilityPercent);
    disp('Angles before GT call:'), whos angles
    disp(angles)
    GT_smooth = imgaussfilt(GT_gray, 1.5);  % sigma = 1 or 1.5 works well
    [Mask_GT, ~] = functionContrastAt5PerCentGT(GT_smooth, S, visibilityPercent, angles);



    %% 3. Edge amplification metric
    epsilon = 1e-6;
    wI = sum(Mask_rain(:)); % = W_I
    wJ = sum(Mask_GT(:)); % = W_J
    e1 = max(0, (wI - wJ)) / (max(wI, wJ) + epsilon);
    
    %% 4. RESPO: Rain-streak Pixel Occupancy for newly saturated pixel detection
    bright_Rain = double(max(Rain, [], 3)); % = B_I, brightness of rainy image I.
    bright_GT   = double(max(GT, [], 3));   % = B_J, , brightness of GT image J.
    kernel = ones(3); % 3x3 box instead of strel
    bright_GT = imresize(bright_GT, size(bright_Rain));
%     size(bright_Rain)
%     size(bright_GT)
%     size(kernel)
    new_saturated = conv2(double((bright_Rain >= brightThresh) & (bright_GT < brightThresh)), kernel, 'same') > 0;
    ns1 = sum(new_saturated(:)) / numel(bright_GT);

    % B_I >= Tb  ↔ pixel is saturated in rainy image.​
    % B_J < Tb   ↔ the same pixel is not saturated in clean image.
    % Logical & → Both together mean the saturation is newly introduced by rain streaks.

    %% 5. Adaptive brightness delta
%     % Candidate edge region
%     Nmap = (edges_Rain==1) & (edges_GT==0);
% 
%     % Absolute brightness difference
%     diff = double(bright_Rain) - double(bright_GT);
% 
%     % Percentile only over candidate region
%     if any(Nmap(:))
%         delta = prctile(abs(diff(Nmap)), 50);  % nth percentile
%     else
%     delta = 0;
%     end

%% 5. Adaptive brightness delta
    k = 7;                                    % neighborhood size
    muJ = imboxfilt(double(bright_GT), k);    
    tau = 2;                                  
    epsv = 1e-6;
    DeltaB = (double(bright_Rain) - double(bright_GT)) ./ (max(muJ, tau) + epsv);
    delta  = prctile(DeltaB(:), 80);

    %% 6. Rain streak Coverage
%     rain_streak_mask = Nmap & (abs(diff) > delta);
%     figure, imshow(rain_streak_mask);
%     size(Mask_rain)
%     size(Mask_GT)
    Mask_GT = imresize(Mask_GT, size(Mask_rain), 'nearest');
    rain_streak_mask = (Mask_rain==1) & (Mask_GT==0) & ...
                   ( (bright_Rain > bright_GT + delta) | ...
                     (bright_Rain < bright_GT - delta) );

    figure, imshow(rain_streak_mask);
    
    mask_clean = adaptiveRainMaskCleanup(rain_streak_mask);
    streak_area = sum(mask_clean(:)) / numel(mask_clean);
    percentage_streak_area = 100 * streak_area;
    figure, imshow(mask_clean); 
    title('rain_streak_refined');
    %  All three conditions must be true at the same pixel
    % (edges_Rain == 1) — pixel must be an edge in the rainy image
    % (edges_GT == 0) — pixel must not be an edge in the ground truth image
    % (abs(diff) > delta) — rain streaks may darken (light absorption) as well as brighten pixels depending on lighting.     
 
    
    %% 7. Visualization (overlay neon green on rain streaks)
    overlay = Rain;

% Neon green RGB
neonR = 57;
neonG = 255;
neonB = 20;

% Apply to masked pixels
overlayR = overlay(:, :, 1);
overlayG = overlay(:, :, 2);
overlayB = overlay(:, :, 3);

overlayR(mask_clean) = neonR;
overlayG(mask_clean) = neonG;
overlayB(mask_clean) = neonB;

overlay(:, :, 1) = overlayR;
overlay(:, :, 2) = overlayG;
overlay(:, :, 3) = overlayB;
% imwrite(overlay, 'res/Stk_245.png');


    %% 8. Output structure
    results = struct();
    results.e1 = e1;
    results.ns1 = ns1;
    results.streak_area = streak_area;
    results.percentage_streak_area = percentage_streak_area;
    results.overlay = overlay;
    
end
