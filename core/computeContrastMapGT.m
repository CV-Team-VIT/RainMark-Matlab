function [Mask, Crr] = functionContrastAt5PerCentGT(I1, S, percentage, angles)
%% Objective:
% Compute visible-edge mask and contrast map for GT (clear) image
% using same 8 sampled orientation angles as used for the rainy image.

if nargin < 3
    percentage = 5;
end
if nargin < 4
    error('You must supply the "angles" array from the rainy image.');
end

[nl, nc, ~] = size(I1);
percentage = percentage / 2;
angles = reshape(angles, 1, []); 
fprintf('Using %d orientation angles transferred from rainy image:\n', numel(angles));
disp(mat2str(angles,3));

if size(angles,2) > 1 && size(angles,1) == 1
    % row vector, correct shape
elseif size(angles,1) > 1 && size(angles,2) == 1
    % column vector, convert to row
    angles = angles';
else
    % if angles accidentally passed as ROI matrix
    angles = unique(angles(:)');
end

%% --- Multi-length structuring elements (same as rainy) ---
lineLengths = 3; % Single-streak length
% lineLengths = [3, 7, 11]; % Multi-streak length

I1pad = padarray(I1, [3 3], 'symmetric');
Imin = inf(size(I1pad));
Imax = -inf(size(I1pad));

for l = lineLengths
    for k = 1:numel(angles)
        se = strel('line', l, angles(k));
        Imin = min(Imin, imerode(I1pad, se, 'same'));
        Imax = max(Imax, imdilate(I1pad, se, 'same'));
    end
end

Imin = Imin(3+(1:nl), 3+(1:nc));
Imax = Imax(3+(1:nl), 3+(1:nc));

I1pad = padarray(I1, [S S], 'symmetric');
Iminpad = padarray(Imin, [S S], 'symmetric');
Imaxpad = padarray(Imax, [S S], 'symmetric');

Mask = false(nl+2*S, nc+2*S);
Crr  = zeros(nl+2*S, nc+2*S);

h = waitbar(0, 'Processing GT image...');

for ii = 1:round(S/2):nl
    for jj = 1:round(S/2):nc
        Is = double(I1pad(S+ii:2*S+ii-1, S+jj:2*S+jj-1));
        Ismin = double(Iminpad(S+ii:2*S+ii-1, S+jj:2*S+jj-1));
        Ismax = double(Imaxpad(S+ii:2*S+ii-1, S+jj:2*S+jj-1));

        Ismin_r = max(1, round(min(Ismin(:))));
        Ismax_r = min(255, round(max(Ismax(:))));

        Fcube = false(S, S, Ismax_r-Ismin_r+1);
        C = zeros(1, Ismax_r);

        for s = Ismin_r:Ismax_r
            pg = 1;
            Cgxx1 = zeros(1, S^2);

            for nn = 2:S
                for mm = 2:S
                    if Ismin(nn, mm) <= s && Ismax(nn, mm) > s
                        Cgxx1(pg) = min(abs(s-Is(nn, mm))/max(s, Is(nn, mm)), ...
                                        abs(s-Is(nn, mm-1))/max(s, Is(nn, mm-1)));
                        pg = pg + 1;
                        Fcube(nn, mm, s-Ismin_r+1)   = true;
                        Fcube(nn, mm-1, s-Ismin_r+1) = true;
                    end
                end
            end

            if pg > 1
                C(s) = sum(Cgxx1)/(pg-1);
            end
        end

        [M, s0] = max(C);
        s0 = max(s0, Ismin_r);
        M = 256*M;

        if M > (256*(percentage/100))
            Mask(S+ii:2*S+ii-1, S+jj:2*S+jj-1) = ...
                Mask(S+ii:2*S+ii-1, S+jj:2*S+jj-1) | Fcube(:,:,s0-Ismin_r+1);

            I3 = Mask(S+ii:2*S+ii-1, S+jj:2*S+jj-1);
            Crr1 = zeros(S,S);
            Crr1(I3) = 2*M/256;
            Crr(S+ii:2*S+ii-1, S+jj:2*S+jj-1) = Crr1;
        end
    end
    waitbar(ii/nl, h);
end

Mask = Mask(S+1:nl+S, S+1:nc+S);
Crr  = Crr(S+1:nl+S, S+1:nc+S);

close(h);
end
