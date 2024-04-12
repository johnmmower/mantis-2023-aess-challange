%% Range Map
clear;

data = load("20240328OceanographyTest/arctic_fox_csv/ArcticFoxRamps.mat");
% dataChirp = data.dataChirp(3087500:4322500,:);
% dataChirp = data.dataChirp(data.dataChirp.ang==0,:);
%dataChirp = data.dataChirp;
%dataChirp = data.datatt;
ramps = data.ramps;
fs = 25E6;
c = 3e8;
rampBW = 500e6;
rampDuration = 600e-6;
rampRate = rampBW/rampDuration;
rampsPerCollect = 3;
beamWidth = 13;
% numCollects = 4;


% M = floor(rampDuration*fs);
M = length(ramps(:,1,1));
% M=6000;
g = rectwin(M);
% L = floor(M/2);
L=0;
RNdft = M*rampsPerCollect;
rampAvg = squeeze((ramps(:,1,:)+ramps(:,2,:)+ramps(:,3,:))/3);



%%
figure;
s = stft(reshape(rampAvg,[],1),fs,Window=hanning(M),OverlapLength=0, ...
         FFTLength=M,FrequencyRange="twosided");
stft(reshape(rampAvg,[],1),fs,Window=hanning(M),OverlapLength=0, ...
         FFTLength=M,FrequencyRange="twosided");
ylim([1 3])
clim([55 85])

figure;
RD = stft(reshape(s',1,[]), Window = hanning(128),FFTLength=128,OverlapLength=0,FrequencyRange="centered", OutputTimeDimension="downrows");
stft(reshape(s',1,[]), Window =hanning(128),FFTLength=128,OverlapLength=0,FrequencyRange="centered",OutputTimeDimension="downrows");
clim([70 100])

%%
X_cfar = abs(s);


% plot the output
figure;
tiledlayout(2,1)
nexttile
plot(X_cfar)

% Apply CFAR to detect the targets by filtering the noise.

% TODO: Define the number of Training Cells
T = 20;
% TODO: Define the number of Guard Cells 
G = 18;
% TODO: Define Offset (Adding room above noise threshold for the desired SNR)
offset = 1.05;

% Initialize vector to hold threshold values 
threshold_cfar = ones(size(X_cfar)) * max(X_cfar)';
signal_cfar = zeros(size(X_cfar));

% Slide window across the signal length
for j = 1:size(s,2)
    for i = 625:725   
    
        % TODO: Determine the noise threshold by measuring it within
        % the training cells
        noise_level = sum(X_cfar(i-(T+G):i-G-1,j))+sum(X_cfar(i+G:i+T+G-1,j));
        % TODO: scale the noise_level by appropriate offset value and take
        % average over T training cells
        threshold = (noise_level/(2*T))*offset;
        % Add threshold value to the threshold_cfar vector
        threshold_cfar(i,j) = threshold;
        
        signal = mean(X_cfar(i-G:i+G,j));
        signal_cfar(i,j) = signal;
    end
end
signal_cfar(signal_cfar<threshold_cfar) = 0;

[~, rangeShift] = max(signal_cfar);
% RangeShift = round(movmean(rangeShift,6));
p = polyfit(1:length(rangeShift),rangeShift,12);
y = polyval(p, 1:length(rangeShift));
% plot(y)
rangeShift = y;

% plot original sig, threshold and filtered signal within the same figure.
nexttile
plot(X_cfar(:,200));
hold on
plot(threshold_cfar(:,200),'r--','LineWidth',2)
hold on
plot (signal_cfar(:,200));
ylim([0 10E3])
legend('Signal','CFAR Threshold','detection')

%%
rampAvg = rampAvg .* exp(((0:M-1)/fs)' * -2i*pi*(rangeShift-mean(rangeShift))*(fs/M));
figure;
s = stft(reshape(rampAvg,[],1),fs,Window=hanning(M),OverlapLength=0, ...
         FFTLength=M,FrequencyRange="twosided");
stft(reshape(rampAvg,[],1),fs,Window=hanning(M),OverlapLength=0, ...
         FFTLength=M,FrequencyRange="twosided");
ylim([1 3])
clim([55 85])


figure;
RD = stft(reshape(s',1,[]), Window = hanning(458),FFTLength=458,OverlapLength=0,FrequencyRange="centered", OutputTimeDimension="downrows");
stft(reshape(s',1,[]), Window =hanning(458),FFTLength=458,OverlapLength=0,FrequencyRange="centered",OutputTimeDimension="downrows");
clim([70 100])

%%
% for k = -90:9:90
%     figure;
%     stft(dataChirp.rx(dataChirp.ang==k,:) ,fs,Window=g,OverlapLength=L, ...
%         FFTLength=Ndft,FrequencyRange="twosided");
%     ylim([.5 .8])
%     title(k)
%     clim([50 100])
% end

% figure;
% for i=0:numCollects-1
%     collect = dataChirp(1+i*M:M+i*M,:);
% 
%     [pxx,f] = periodogram(collect.rx ,g, RNdft,fs,'twosided','power');
%     sumf = fft(collect.rx);
%     delf = fft(collect.del);
% 
%     range = c*(f-506e3)/(2*rampRate);
%     rMax = 40;
%     idx = find(range > 0 & range < rMax);
% 
%     wedge = deg2rad(collect.ang(1)-beamWidth/2:1:collect.ang(1)+beamWidth/2)*-1 +pi/2;
%     [x,y] = pol2cart(wedge',range(idx)');
%     z = meshgrid(pxx(idx),ones(1,length(wedge)));
%     surf(x,y,z,EdgeColor = 'none')
%     title(string(collect.Time(end)))
%     axis([-50 50 0 50 0 100])    
%     view(0,90)
%     colorbar
%     clim([50 100])
%     % pause(2e-3)
%     % drawnow;
%     hold on  
% end
