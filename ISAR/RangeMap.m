%% ISAR Image
clc;
clear;

data = load("20240328OceanographyTest/RVLeeThompsonSpin/SpinRamps.mat");
ramps = data.ramps;
fs = 25E6;                      %Sample Rate (Hz)
rampsPerCollect = 3;            %Ramps per collect    
numCollects = 4;                %Number of collects
nRamp = length(ramps(:,1,1));   %Ramp length
rampAvg = squeeze((ramps(:,1,:)+ramps(:,2,:)+ramps(:,3,:))/3);

%If working towards automation,a good approach would be to implement 2D
%range-doppler CFAR to detect rotating vessels. This should aid in
%selection of range and cross range extents of your ISAR image. Rotational
%velocity needs to be predicted or measured to decide the coherent
%integration time of your vessel of interest.

%Approximate Range extents for perpendicular collects
xRange = [[.735 .77];[.73 .78];[.74 .78];[.735 .775];[.745 .775]; ...
                [.75 .8];[.765 .8];[.76 .81];[.775 .815];[.78 .83]];
%Approximate collects where vessel is perpendicular
collectNum = [174 366 551 730 873 1088 1267 1446 1625 1804];

%Interpolating between perpendicular collects gives approximatly .5 degrees
%of rotation per collect. Aim to integrate over 6 degees or less under
%small angle assumption
numIntegCollects = 12;
nfftCrossRange = rampsPerCollect * numIntegCollects;

%Create ISAR images at j index of perpendicular collectNum 
%and sweep over i collects
for j = 5
    for i = -7:7
        %Create range map spectrogram over integration collects
        s = spectrogram(reshape(ramps(:,1:3,collectNum(j)+i:collectNum(j)+numIntegCollects+i),[],1),rectwin(nRamp),0,nRamp,fs,"twosided","power");
        % xlim([.5 1.5])
        % clim([-60 10])
        % title("Range Map")
        % xlabel("Range")
        % ylim([.5 1.5])
        % clim([55 85])
        
        %Create and plot ISAR image
        figure;
        spectrogram(reshape(s',[],1),hamming(nfftCrossRange),0,nfftCrossRange,fs,"centered","power","yaxis");
        title("ISAR Sweep")
        clim([45 75])
        ylabel("Cross Range")
        xlim(xRange(j,:))
        xlabel("Range")
        set(gca, 'XTick', [], 'YTick', []);
        
    end
end
