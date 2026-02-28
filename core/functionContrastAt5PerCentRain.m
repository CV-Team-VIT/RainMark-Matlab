function [Mask, Crr, dominantAnglePrimary, dominantAngleWeighted, ROI, angles] = functionContrastAt5PerCentRain(I1, S, percentage)
%% Objective:
% Identify visibly contrasting edges in a grayscale image I1
% based on local contrast estimation using Weber contrast.
% Outputs also include dominant orientation and 8 sampled angles (for GT use).

%% Inputs
% I1 : Grayscale input image
% S  : Local patch size (default 7)
% percentage : Minimum contrast visibility threshold (default 5%)

%% Outputs
% Mask  : Binary mask of visible edges
% Crr   : Contrast map
% dominantAnglePrimary  : Primary orientation peak (deg)
% dominantAngleWeighted : Weighted average orientation (deg)
% ROI   : Adaptive orientation intervals (deg)
% angles: 1×N vector of sampled directions for morphology & GT reuse

if nargin < 1, error('Not enough arguments'); end
if nargin < 2, S = 7; end
if nargin < 3, percentage = 5; end

percentage = percentage / 2;  % split for Weber computation
[nl, nc, ~] = size(I1);

%% --- Gradient analysis ---
[Gx, Gy] = imgradientxy(I1, 'sobel');
[Gmag, ~] = imgradient(Gx, Gy);
Gdir = atan2(Gy, Gx) * 180/pi;
Gdir180 = mod(Gdir, 180);

magThresh = 0.2 * max(Gmag(:));
validAngles = Gdir180(Gmag > magThresh);

edges = 0:5:180;
[counts, edges] = histcounts(validAngles, edges);
binCenters = edges(1:end-1) + diff(edges)/2;

%% --- Adaptive ROI & dominant angles ---
tolerance = 5;  % degrees near 0/180 considered vertical
[dominantAnglePrimary, dominantAngleWeighted, ROI, ~, peakAngles] = ...
    findAdaptiveROI_Check(binCenters, counts, tolerance);

%% --- Direction classification ---
if (dominantAnglePrimary >= 0 && dominantAnglePrimary <= 15) || (dominantAnglePrimary >= 165 && dominantAnglePrimary <= 180)
    direction = 'Near-vertical (↓)';
elseif dominantAnglePrimary > 105 && dominantAnglePrimary <= 165
    direction = 'Right-slanted (↘)';
elseif dominantAnglePrimary > 15 && dominantAnglePrimary <= 75
    direction = 'Left-slanted (↙)';
else
    direction = 'Near-horizontal (→)';
end

edgeAngle = mod(dominantAnglePrimary + 90, 180);

%% --- Robust sampling of orientation angles from ROI ---
numAngles = 8;

% Validate ROI shape
if isempty(ROI)
    ROI = [0 180];
elseif isvector(ROI) && numel(ROI)==1
    ROI = [ROI-5 ROI+5];
elseif size(ROI,2) ~= 2
    error('ROI must be Nx2: [start end] degrees.');
end

ROI(:,1) = max(0, ROI(:,1));
ROI(:,2) = min(180, ROI(:,2));
widths = max(0, ROI(:,2)-ROI(:,1));
totalWidth = sum(widths);
if totalWidth <= 0
    ROI = [0 180];
    widths = 180;
    totalWidth = 180;
end

angles = zeros(1,numAngles);
idx = 1;
for r = 1:size(ROI,1)
    w = widths(r);
    nSamples = max(1, round(numAngles * (w/totalWidth)));
    if idx + nSamples - 1 > numAngles
        nSamples = numAngles - idx + 1;
    end
    angles(idx:idx+nSamples-1) = linspace(ROI(r,1), ROI(r,2), nSamples);
    idx = idx + nSamples;
end

if idx <= numAngles
    angles(idx:end) = linspace(ROI(1,1), ROI(end,2), numAngles-idx+1);
end

angles = angles(1:numAngles);
angles = reshape(angles,1,[]);  % always return as 1×N

%% --- ROI Display ---
if isempty(ROI)
    fprintf('ROI = [ ] (no valid regions detected)\n');
elseif size(ROI,1)==1
    fprintf('ROI = [%.2f°, %.2f°]\n', ROI(1,1), ROI(1,2));
else
    fprintf('ROI = ');
    for i = 1:size(ROI,1)
        fprintf('[%.2f°, %.2f°]', ROI(i,1), ROI(i,2));
        if i < size(ROI,1), fprintf(' ∪ '); end
    end
    fprintf('\n');
end

fprintf('Dominant Gradient Angle θ = %.2f°\n', dominantAnglePrimary);
fprintf('Edge Orientation φ = %.2f°\n', edgeAngle);
fprintf('Detected Rain Streak Type = %s\n', direction);
fprintf('Angles sampled for RainMark: %s\n', mat2str(angles,3));

%% --- Orientation histogram plot ---
figure('Color','w','Position',[200 200 900 500]);
hold on; grid on; box on;
bar(binCenters,counts,'FaceColor',[0.6 0.8 1.0],'EdgeColor','k','BarWidth',1);
yMax = max(counts)*1.1;
for r = 1:size(ROI,1)
    patch([ROI(r,1) ROI(r,2) ROI(r,2) ROI(r,1)], [0 0 yMax yMax], ...
        [1 0.85 0.85], 'FaceAlpha', 0.35, 'EdgeColor','none');
end
if exist('peakAngles','var') && ~isempty(peakAngles)
    peakCounts = interp1(binCenters, counts, peakAngles, 'linear', 'extrap');
    scatter(peakAngles, peakCounts, 80, 'filled', 'MarkerFaceColor',[0 0.5 0], 'MarkerEdgeColor','k');
end
if exist('dominantAnglePrimary','var')
    plot([dominantAnglePrimary dominantAnglePrimary],[0 yMax],'r--','LineWidth',2);
end
if exist('dominantAngleWeighted','var')
    plot([dominantAngleWeighted dominantAngleWeighted],[0 yMax],'m-.','LineWidth',2);
end
xlabel('Orientation (degrees)','FontSize',12,'FontWeight','bold');
ylabel('Frequency','FontSize',12,'FontWeight','bold');
title('Orientation Histogram with Dominant Angles and Adaptive ROIs',...
    'FontSize',14,'FontWeight','bold');
xlim([0 180]); ylim([0 yMax]); hold off;

%% --- Morphological processing along sampled angles ---
lineLengths = 3; % Single-streak length
% lineLengths = [3, 7, 11]; % Multi-streak length
% Pad enough for the largest structuring element half-extent
P = ceil(max(lineLengths)/2);                 % e.g., 13 -> 7
I1pad = padarray(I1, [P P], 'symmetric');
I1padD = double(I1pad);
Imin = +inf(size(I1pad));
Imax = -inf(size(I1pad));

for l = lineLengths
    for k = 1:numel(angles)
        se = strel('line', l, angles(k));

        E = imerode(I1padD, se);
        D = imdilate(I1padD, se);

        Imin = min(Imin, E);
        Imax = max(Imax, D);
    end
end

Imin = Imin(P+(1:nl),P+(1:nc));
Imax = Imax(P+(1:nl),P+(1:nc));

I1pad   = padarray(I1,   [S S],'symmetric');
Iminpad = padarray(Imin, [S S],'symmetric');
Imaxpad = padarray(Imax, [S S],'symmetric');

Mask = false(nl+2*S,nc+2*S);
Crr  = zeros(nl+2*S,nc+2*S);

h = waitbar(0,'Computing RainMark Contrast...');

for ii = 1:round(S/2):nl
    for jj = 1:round(S/2):nc
        Is    = double(I1pad(  S+ii:2*S+ii-1,   S+jj:2*S+jj-1));
        Ismin = double(Iminpad(S+ii:2*S+ii-1,   S+jj:2*S+jj-1));
        Ismax = double(Imaxpad(S+ii:2*S+ii-1,   S+jj:2*S+jj-1));

        Ismin_r = max(1, round(min(Ismin(:))));
        Ismax_r = min(255, round(max(Ismax(:))));
        Fcube = false(S, S, Ismax_r-Ismin_r+1);
        C = zeros(1, Ismax_r);

        for s = Ismin_r:Ismax_r
            pg = 1;
            Cgxx1 = zeros(1, S^2);
            for nn = 2:S
                for mm = 2:S
                    if Ismin(nn,mm) <= s && Ismax(nn,mm) > s
                        Cgxx1(pg) = min(abs(s-Is(nn,mm))/max(s,Is(nn,mm)), ...
                            abs(s-Is(nn,mm-1))/max(s,Is(nn,mm-1)));
                        pg = pg + 1;
                        Fcube(nn,mm,s-Ismin_r+1)   = true;
                        Fcube(nn,mm-1,s-Ismin_r+1) = true;
                    end
                end
            end
            if pg > 1
                C(s) = sum(Cgxx1)/(pg-1);
            end
        end

        [M,s0] = max(C);
        s0 = max(s0, Ismin_r);
        M = 256*M;

        if M > (256*(percentage/100))
            Mask(S+ii:2*S+ii-1, S+jj:2*S+jj-1) = ...
                Mask(S+ii:2*S+ii-1, S+jj:2*S+jj-1) | Fcube(:,:,s0-Ismin_r+1);

            I3 = Mask(S+ii:2*S+ii-1, S+jj:2*S+jj-1);
            Crr1 = zeros(S,S);
            Crr1(I3) = 2*M/256;
            % --- FIXED indexing bug here ---
            Crr(S+ii:2*S+ii-1, S+jj:2*S+jj-1) = Crr1;
        end
    end
    waitbar(ii/nl,h);
end

% Crop final results
Mask = Mask(S+1:nl+S, S+1:nc+S);
Crr  = Crr( S+1:nl+S, S+1:nc+S);

close(h);

% --- Final shape safeguard before return ---
angles = reshape(angles,1,[]);
fprintf('DEBUG — Final sampled angles (1×%d): %s\n', numel(angles), mat2str(angles,3));

end
