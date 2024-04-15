%% Align Ramps, Window, Correct Phase Incoherence
clc;
clear;

data = load("20240328OceanographyTest/RVLeeThompsonSpin/SpinData.mat");
data = data.datatt;
fs = 25E6;            %Sample Rate(Hz)
N = 49500;            %Buffer size
nRamp = 12827;        %Linear Ramp Length
nRampEnds = 2200;     %Non-Linear Ramp Ends Length
n = nRamp+nRampEnds;  %Ramp repetition interval
numRamp = 3;          %Ramps per collect
numCollect = 1329;    %Number of collects

%Find DC path frequency index. 500kHz in our case
freqs = fs/nRamp*(0:nRamp-1);
DCFreqIdx = find(freqs > 500e3 & freqs < 501e3);
DPFreqsIdx = find(freqs > 490e3 & freqs < 510e3);


%Preallocate 3D array (ramps timeseries) x (number of ramps) x (number of collects)                             
ramps = zeros(nRamp,numRamp,numCollect+1);

%For subarray processing
% rampsL = zeros(nRamp,numRamp,numCollect+1);
% rampsR = zeros(nRamp,numRamp,numCollect+1);

% figure;
% hold on;

%Align Ramps, Window, Correct Phase Incoherence
for i=0:numCollect
    collect = data(1+N*i:N*i+N,:);
    ramps(:,:,i+1) = [data.rx(1+N*i:N*i+n-nRampEnds,:).*hamming(nRamp),data.rx(1+n+N*i:N*i+2*n-nRampEnds,:).*hamming(nRamp),data.rx(1+2*n+N*i:N*i+3*n-nRampEnds,:).*hamming(nRamp)];

    %plot ramp magnitude to check rough alignment
    % figure;
    % plot(abs([data.rx(1+N*i:N*i+n-2200,:).*hamming(nRamp),data.rx(1+n+N*i:N*i+2*n-2200,:).*hamming(nRamp),data.rx(1+2*n+N*i:N*i+3*n-2200,:).*hamming(nRamp)]))
    
    %For subarray processing
    % rampsL(:,:,i+1) = [data.LeftArrayRx(1+N*i:N*i+n-2200,:).*hamming(nRamp),data.LeftArrayRx(1+n+N*i:N*i+2*n-2200,:).*hamming(nRamp),data.LeftArrayRx(1+2*n+N*i:N*i+3*n-2200,:).*hamming(nRamp)];
    % rampsR(:,:,i+1) = [data.RightArrayRx(1+N*i:N*i+n-2200,:).*hamming(nRamp),data.RightArrayRx(1+n+N*i:N*i+2*n-2200,:).*hamming(nRamp),data.RightArrayRx(1+2*n+N*i:N*i+3*n-2200,:).*hamming(nRamp)];
    
    %DFT around DC path frequency
    directPathDFT = goertzel(ramps(:,:,i+1),DPFreqsIdx);

    %plot magnitude near DC path frequency
    % figure;
    % plot(DPFreqs(DPFreqsIdx),abs(directPathDFT)/length(directPathDFT))

    %plot phase near DC path frequency
    % figure;
    % plot(freqs(DPFreqsIdx),angle(directPathDFT))
    % xlabel("Frequency")
    % ylabel("Phase")
    % title("Incoherent Phase")

    %Measure phase offset from DC path and correct it for the entire ramp
    phaseCorrection = angle(directPathDFT(DCFreqIdx-DPFreqsIdx(1),:));
    ramps(:,:,i+1) =  ramps(:,:,i+1).*exp(-1i*phaseCorrection);
    %For subarray processing
    % rampsL(:,:,i+1) =  rampsL(:,:,i+1).*exp(-1i*phaseCorrection);
    % rampsR(:,:,i+1) =  rampsR(:,:,i+1).*exp(-1i*phaseCorrection);

    %Check phase correction
    directPathDFT = goertzel(ramps(:,:,i+1),DPFreqsIdx);
    %Plot phase near DC path for corrected, coherent signal
    % figure;
    % plot(freqs(DPFreqsIdx),angle(directPathDFT))
    % xlabel("Frequency")
    % ylabel("Phase")
    % title("Coherent Phase")
end
%Save ramps
