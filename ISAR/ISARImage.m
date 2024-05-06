%% Chirp Pulse Range-Doppler ISAR

%% ISAR Image
clc;
clear;

%Load Preprocessed Time Series Data
data = load("20240502OceanographyTest/flyby1Ramps.mat");
ramps = data.ramps;

% % For subarray Processing
% data = load("20240502OceanographyTest/flyby1RampsR.mat");
% rampsR = data.rampsR;
% data = load("20240502OceanographyTest/flyby1RampsL.mat");
% rampsL = data.rampsL;
% rampsDiff = rampsL - rampsR;

%Load Time Stamps
data = load("20240502OceanographyTest/flyby1RampsT.mat");
rampsT = data.rampsT;

%Load Relative Heading and Ranges from GPS Data or from other localization
%or tracking techniques
%If working towards automation,a good approach would be to implement 2D
%range-doppler CFAR to detect rotating vessels. This should aid in
%selection of range and cross range extents of your ISAR image. Rotational
%velocity needs to be predicted or measured to decide the coherent
%integration time of your vessel of interest. Rotation can be either in
%place or changes in relative heading between the vessel and your radar
data = load("20240502OceanographyTest/flyby1RB.mat");
ranges = movmean(data.RangeBearings(1,:),12);
bearings = 360-(225+12+movmean(data.RangeBearings(2,:),12));

%Calculate range rate and rotation rate
rangeRate = movmean(diff(ranges)./seconds(diff(rampsT(1,1:end-1))),12);
rotRate = movmean(diff(bearings)./seconds(diff(rampsT(1,1:end-1))),12);

c = 3e8;                        %Speed of light (m/s)
fc = 10e9;                      %Center Frequency (Hz)
rampBW = 500e6;                 %Ramp Bandwidth (Hz)
rampDuration = 600e-6;          %Ramp Duration (s)
rampRate = rampBW/rampDuration;
fs = 25E6;                      %Sample Rate (Hz)
nRamp = length(ramps(:,1,1));   %Ramp length

%Vessel Information
BoatL = 10;
BoatW = 4;

%Average Ramps within a collect for better SNR
rampAvg = squeeze((ramps(:,1,:)+ramps(:,2,:)+ramps(:,3,:))/3);
% %For Subarray Processing
% rampDiff = squeeze((rampsDiff(:,1,:)+rampsDiff(:,2,:)+rampsDiff(:,3,:))/3);

% Create Range Profiles and Range axis values
rangeFFT = fft(rampAvg);
% diffFFT = fft(rampDiff);
rangef =  fs/size(rangeFFT,1)*(0:(size(rangeFFT,1)));
range = (c*(rangef-500e3))/(2*rampRate);
%Range of Interest
rangeIdx = find(98<range & range<110);

%Initialize Motion Compensated Time Series Data
comprampAvg = zeros(size(rangeFFT));

for i = 9:12
    
    %Cross Range of Interest
    slowTIdx = find(abs(bearings+i)<2);

    %Range Plot with track
    % figure;
    % hold on;
    % rangePlot = image(rampsT(1,slowTIdx),range(rangeIdx),squeeze(mag2db(abs(rangeFFT(rangeIdx,slowTIdx)))));
    % set(gca,'YDir','normal')
    % set(rangePlot,'CDataMapping','scaled')
    % title("Uncompensated")
    % colorbar;
    % clim([55 75])
    % plot(rampsT(1,slowTIdx),ranges(slowTIdx),'Color','r','LineWidth',2);
    % hold off;
    % 
    % %Plot track in polar coordinates
    % figure;
    % polarplot(deg2rad(bearings(slowTIdx)),ranges(slowTIdx));

    %Range and Doppler compensation
    rangeShift = ranges(slowTIdx)-ranges(slowTIdx(end));
    dopplerShift = fc*(rangeRate+c)/c-fc;
    fShift = ((rangeShift * (2*rampRate)) / c)+dopplerShift(slowTIdx);

    comprampAvg(:,slowTIdx) = rampAvg(:,slowTIdx) .* exp(((0:nRamp-1)/fs)' * -2i*pi*(fShift));
    comprangeFFT = fft(comprampAvg);

    % %Range Plot after Motion Compensation
    % figure;
    % rangeCorrectedPlot = image(rampsT(1,slowTIdx),range(rangeIdx),squeeze(mag2db(abs(comprangeFFT(rangeIdx,slowTIdx)))));
    % set(gca,'YDir','normal')
    % set(rangeCorrectedPlot,'CDataMapping','scaled')
    % colorbar;
    % title("Range and Doppler Compensated")
    % clim([55 75])
    
    % Create Slow Time, Doppler Frequency, and cross range axis values
    uniformSlowT = linspace(0,rampsT(1,slowTIdx(end))-rampsT(1,slowTIdx(1)),length(slowTIdx));
    slowT = seconds(reshape(rampsT(1,slowTIdx),1,[])-rampsT(1,slowTIdx(1)));
    dopplerf = (1/(seconds(diff(uniformSlowT(1:2))))./length(uniformSlowT))*(-(length(uniformSlowT))/2:(length(uniformSlowT))/2);
    xRange = (dopplerf + fc)*(c/fc)-c;
   
    %Cross Range FFT
    XrangeFFT = fftshift(fft(hamming(length(slowTIdx))'.*reshape(comprangeFFT(rangeIdx,slowTIdx),length(rangeIdx),[]),[],2),2);

    % %Plot ISAR Image with Frequencies and Ranges on same plot
    % figure;
    % ISARPlot = image(xRange,rangef(rangeIdx)*10e-6,mag2db(abs(XrangeFFT)));
    % ax1 = gca;
    % set(ISARPlot,'CDataMapping','scaled')
    % xlabel('Cross Range Doppler (Hz)')
    % ylabel('Range Beat Frequency (MHz)')
    % set(ax1,'YDir','normal','XAxisLocation','top','YAxisLocation','right')
    % ax2 = axes('XAxisLocation','bottom','YAxisLocation','left');
    % 
    % ISARPlot2 = image(dopplerf,range(rangeIdx),mag2db(abs(XrangeFFT)),'Parent',ax2);
    % set(gca,'YDir','normal')
    % set(ISARPlot2,'CDataMapping','scaled')
    % xlabel('Cross Range (m)')
    % ylabel('Range (m)')
    % clim([68 100])

    %Plot ISAR Image
    ISARPlot = image(dopplerf,range(rangeIdx),mag2db(abs(XrangeFFT)));
    set(gca,'YDir','normal')
    set(ISARPlot,'CDataMapping','scaled')
    clim([75 110])
    colorbar;

end

