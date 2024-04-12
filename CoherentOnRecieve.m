%% Coherent on Recieve
% clear;

data = load("20240328OceanographyTest/arctic_fox_csv/ArcticFoxData.mat");
data = data.datatt;
fs = 25E6;
N = 49500;
n = 15027;
nRamp = 12827;
numCollect = 457;


DPFreqs = fs/nRamp*(0:nRamp-1);
DPFreqsIdx = find(DPFreqs > 490e3 & DPFreqs < 520e3);
DCFreqIdx = find(DPFreqs > 500e3 & DPFreqs < 501e3);
% DPFreqIdx = 1:length(DPFreq);
windowLen = 6000;
rampLen = 7200;
edgeBuff = (rampLen-windowLen)/2;

dataChirp = zeros(windowLen*numCollect,3);
dataChirpT = data.Time(ones(windowLen*numCollect,1));

% for i=40:60
%     collect = data(1+N*i:N*i+N,:);
%     % collect.rx = collect.LeftArrayRx + collect.RightArrayRx;
%     collect.del = collect.LeftArrayRx - collect.RightArrayRx;
% 
%     directPathDFT = goertzel(collect.rx,DPFreqIdx);
%     % figure;
%     % plot(DPFreq(DPFreqIdx),abs(directPathDFT)/length(directPathDFT))
%     [~,idx] = max(directPathDFT);
%     DPFreqFilt = DPFreq(DPFreqIdx([idx-1,idx+1]));
% 
% 
%     filteredCollect = bandpass(collect.rx,DPFreqFilt,fs);
%     % filteredCollect = bandstop(collect.rx,DPFreqFilt,fs);
%     difPhase = diff(unwrap(angle(filteredCollect)));
%     [~,idx] = max(difPhase(1:end-rampLen));
%     rampIdx = idx+edgeBuff:idx+edgeBuff+windowLen-1;
%     figure;
%     plot(difPhase);
%     % plot(angle(filteredCollect))
%     hold on;
%     plot(rampIdx(1:end-1),diff(unwrap(angle(filteredCollect(rampIdx).*hamming(windowLen)))))
%     hold off
%     % 
%     % dataChirp(1+i*windowLen:windowLen+i*windowLen,:) = [collect.rx(rampIdx).*hamming(windowLen),collect.del(rampIdx).*hamming(windowLen),collect.SteerAngleDeg(rampIdx)];
%     % dataChirpT(1+i*windowLen:windowLen+i*windowLen) = collect.Time(rampIdx);
% 
% 
%     % figure;
%     % ylim([.25 .275])
%     % hold on
%     % for j = 0:340
%     %     plot(collect.Time(48*j+1:48*j+48),difPhase(48*j+1:48*j+48))
%     % end
%     % hold off
% 
%     figure;
%     subplot(3,1,1)
%     periodogram(collect.rx,[],[], fs);
%     xlim([0,12])
%     subplot(3,1,2)
%     xlim auto
%     plot(collect.Time,abs(collect.rx))
%     subplot(3,1,3)
%     plot(collect.Time(1:end-1),diff(unwrap(angle(collect.rx))))
%     % spectrogram(collect.rx,[],0,[],12E6,'yaxis')
%     % ylim([0,12])
% end
% dataChirp = array2timetable(dataChirp, ...
%         'RowTImes',datetime(dataChirpT,'InputFormat','yyyy-MM-dd HH:mm:ss.SSSSSS'), ...
%         'VariableNames', {'rx','del','ang'});
% legend();




ramps = zeros(nRamp,3,numCollect+1);
rampsL = zeros(nRamp,3,numCollect+1);
rampsR = zeros(nRamp,3,numCollect+1);
figure;
hold on
for i=0:numCollect
    collect = data(1+N*i:N*i+N,:);
    ramps(:,:,i+1) = [data.rx(1+N*i:N*i+n-2200,:).*hamming(nRamp),data.rx(1+n+N*i:N*i+2*n-2200,:).*hamming(nRamp),data.rx(1+2*n+N*i:N*i+3*n-2200,:).*hamming(nRamp)];
    rampsL(:,:,i+1) = [data.LeftArrayRx(1+N*i:N*i+n-2200,:).*hamming(nRamp),data.LeftArrayRx(1+n+N*i:N*i+2*n-2200,:).*hamming(nRamp),data.LeftArrayRx(1+2*n+N*i:N*i+3*n-2200,:).*hamming(nRamp)];
    rampsR(:,:,i+1) = [data.RightArrayRx(1+N*i:N*i+n-2200,:).*hamming(nRamp),data.RightArrayRx(1+n+N*i:N*i+2*n-2200,:).*hamming(nRamp),data.RightArrayRx(1+2*n+N*i:N*i+3*n-2200,:).*hamming(nRamp)];
    
    directPathDFT = goertzel(ramps(:,:,i+1),DPFreqsIdx);
    % plot(DPFreqs(DPFreqsIdx),abs(directPathDFT)/length(directPathDFT))
    [~,idx] = max(directPathDFT);
    DPFreqIdx = DPFreqsIdx(idx);
    DPFreq = DPFreqs(DPFreqIdx);
    % plot(DPFreqs(DPFreqsIdx),angle(directPathDFT))
    phaseCorrection = angle(directPathDFT(DCFreqIdx-DPFreqsIdx(1),:));
    ramps(:,:,i+1) =  ramps(:,:,i+1).*exp(-1i*phaseCorrection);
    rampsL(:,:,i+1) =  rampsL(:,:,i+1).*exp(-1i*phaseCorrection);
    rampsR(:,:,i+1) =  rampsR(:,:,i+1).*exp(-1i*phaseCorrection);

    directPathDFT = goertzel(ramps(:,:,i+1),DPFreqsIdx);
    % plot(DPFreqs(DPFreqsIdx),abs(directPathDFT)/length(directPathDFT))
    [~,idx] = max(directPathDFT);
    DPFreqIdx = DPFreqsIdx(idx);
    DPFreq = DPFreqs(DPFreqIdx);
    % plot(DPFreqs(DPFreqsIdx),angle(directPathDFT))

    % figure;
    % plot(abs(ramps))
    % figure;
    % plot(diff(unwrap(angle(ramps))))

    % figure;
    % subplot(3,1,1)
    % periodogram(collect.rx,[],[], fs);
    % xlim([0,12])
    % subplot(3,1,2)
    % xlim auto
    % plot(collect.Time,abs(collect.rx))
    % plot(abs(ramps))
    % subplot(3,1,3)
    % plot(collect.Time(1:end-1),diff(unwrap(angle(collect.rx))))
    % % spectrogram(collect.rx,[],0,[],12E6,'yaxis')
    % % ylim([0,12])

    % figure;
    % subplot(3,1,1)
    % periodogram(ramps,[],[], fs);
    % xlim([0,12])
    % subplot(3,1,2)
    % xlim auto
    % plot(mag2db(abs(ramps)))
    % subplot(3,1,3)
    % plot(diff(unwrap(angle(ramps))))
end

