v = VideoReader('/Users/debayan/Documents/CV Team/RainMark-Matlab/video_processing/videos/video3/v3.mp4');

outDir = '/Users/debayan/Documents/CV Team/RainMark-Matlab/video_processing/videos/video3/rainy/';
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

frame_id = 1;

while hasFrame(v)
    img = readFrame(v);
    imwrite(img, fullfile(outDir, sprintf('frame_%06d.png', frame_id)));
    frame_id = frame_id + 1;
end

fprintf('Saved %d frames.\n', frame_id - 1);