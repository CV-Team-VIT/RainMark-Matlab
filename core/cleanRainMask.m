function mask_clean = adaptiveRainMaskCleanup(mask)
    % Ensure binary logical
    mask = mask > 0;

    % --- Count components before cleanup ---
    CC_before = bwconncomp(mask);
%     fprintf('Components before cleanup: %d\n', CC_before.NumObjects);

    % --- Get blob sizes ---
    stats = regionprops(mask, 'Area');
    if isempty(stats)
        mask_clean = mask;
        fprintf('No blobs found.\n');
        return;
    end
    areas = [stats.Area];

    % --- Adaptive cutoff ---
    cutoff = 1.5 * median(areas);  % or prctile(areas, 75) / 2
    cutoff = max(10, round(cutoff));  % safety lower bound

    % --- Remove small blobs ---
    mask_clean = bwareaopen(mask, cutoff);

    % --- Count components after cleanup ---
    CC_after = bwconncomp(mask_clean);
%     fprintf('Components after cleanup: %d\n', CC_after.NumObjects);
end
