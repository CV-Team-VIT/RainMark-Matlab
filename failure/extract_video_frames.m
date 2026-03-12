% extract_video_frames.m
clc; clear; close all;

% --- PATHS SECTION ---
video_path = '/Users/debayan/Documents/CV Team/RainMark-Matlab/upload1.mp4'; % Example video
output_frames_folder = '/Users/debayan/Documents/CV Team/RainMark-Matlab/failure/video1/frames';
start_time_seconds = 0; % Starting time in the video (seconds)
% ---------------------

interval_length_seconds = 5;

if ~exist(output_frames_folder, 'dir')
    mkdir(output_frames_folder);
end

try
    v = VideoReader(video_path);
catch ME
    error('Could not load video. Please check video_path. Error: %s', ME.message);
end

% Set the start time
v.CurrentTime = start_time_seconds;
end_time_seconds = start_time_seconds + interval_length_seconds;

frame_id = 1;
fprintf('Extracting frames from %.2f sec to %.2f sec...\n', start_time_seconds, end_time_seconds);

% Continuously read until the 5 second interval is up
while hasFrame(v) && v.CurrentTime <= end_time_seconds
    img = readFrame(v);
    
    frame_filename = sprintf('frame_%06d.png', frame_id);
    imwrite(img, fullfile(output_frames_folder, frame_filename));
    
    frame_id = frame_id + 1;
end

fprintf('Finished. Saved %d frames to %s.\n', frame_id - 1, output_frames_folder);
