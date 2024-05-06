%% Align Ramps, Window, Correct Phase Incoherence, Syncronize with GPS Data
clc;
clear;

data = load("20240502OceanographyTest/flyby1Data.mat");
data = data.datatt;
fs = 25E6;            %Sample Rate(Hz)
N = 49500;            %Buffer size
nRamp = 12827;        %Linear Ramp Length
nRampEnds = 2100;     %Non-Linear Ramp Ends Length
n = nRamp+nRampEnds;  %Ramp repetition interval
numRamp = 3;          %Ramps per collect
numCollect = 2100;    %Number of collects

%Find DC path frequency index. 500kHz in our case
freqs = fs/nRamp*(0:nRamp-1);
DCFreqIdx = find(freqs > 500e3 & freqs < 501e3);
DPFreqsIdx = find(freqs > 490e3 & freqs < 510e3);


%Preallocate 3D array (ramps timeseries) x (number of ramps) x (number of collects)                             
ramps = zeros(nRamp,numRamp,numCollect+1);
%Preallocated time array for beginning of each ramp
rampsT = NaT(numRamp,numCollect+1);

%For subarray processing
% rampsL = zeros(nRamp,numRamp,numCollect+1);
% rampsR = zeros(nRamp,numRamp,numCollect+1);

% figure;
% hold on;

%Align Ramps, Window, Correct Phase Incoherence
for i=0:numCollect
    collect = data(1+N*i:N*i+N,:);
    ramps(:,:,i+1) = ifft(flip(fft([data.rx(1+N*i:N*i+n-nRampEnds,:).*hamming(nRamp),data.rx(1+n+N*i:N*i+2*n-nRampEnds,:).*hamming(nRamp),data.rx(1+2*n+N*i:N*i+3*n-nRampEnds,:).*hamming(nRamp)])));
    rampsT(:,i+1) = [data.Time(1+N*i),data.Time(1+n+N*i),data.Time(1+2*n+N*i)];

    %plot ramp magnitude to check rough alignment
    % figure;
    % plot(abs([data.rx(1+N*i:N*i+n-nRampEnds,:).*hamming(nRamp),data.rx(1+n+N*i:N*i+2*n-nRampEnds,:).*hamming(nRamp),data.rx(1+2*n+N*i:N*i+3*n-nRampEnds,:).*hamming(nRamp)]))
    
    %For subarray processing
    % rampsL(:,:,i+1) = ifft(flip(fft([data.LeftArrayRx(1+N*i:N*i+n-nRampEnds,:).*hamming(nRamp),data.LeftArrayRx(1+n+N*i:N*i+2*n-nRampEnds,:).*hamming(nRamp),data.LeftArrayRx(1+2*n+N*i:N*i+3*n-nRampEnds,:).*hamming(nRamp)])));
    % rampsR(:,:,i+1) = ifft(flip(fft([data.RightArrayRx(1+N*i:N*i+n-nRampEnds,:).*hamming(nRamp),data.RightArrayRx(1+n+N*i:N*i+2*n-nRampEnds,:).*hamming(nRamp),data.RightArrayRx(1+2*n+N*i:N*i+3*n-nRampEnds,:).*hamming(nRamp)])));
    
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
    rampsL(:,:,i+1) =  rampsL(:,:,i+1).*exp(-1i*phaseCorrection);
    rampsR(:,:,i+1) =  rampsR(:,:,i+1).*exp(-1i*phaseCorrection);

    %Check phase correction
    directPathDFT = goertzel(ramps(:,:,i+1),DPFreqsIdx);
    %Plot phase near DC path for corrected, coherent signal
    % figure;
    % plot(freqs(DPFreqsIdx),angle(directPathDFT))
    % xlabel("Frequency")
    % ylabel("Phase")
    % title("Coherent Phase")
end
%Save ramps and rampsT


%%GPS Data
gps = readtable('20240502OceanographyTest/RVLT_radar_gps_050224.csv');

% assign appropriate lat lon pair to each timestamp
gps_times = table2array(gps(:,"time_posix"));
for i=1:numCollect
    
    gps_idx = find(gps_times - ...
        double(convertTo(datetime(rampsT(1,i), 'TimeZone', 'America/Los_Angeles'), 'epochtime')) == 0);
    idx = cast(gps_idx(1), "int32");
    lat = gps(idx, "lat");
    lon = gps(idx, "lon");
    lats(i) = lat.(1); % use first matched index to pick row
    lons(i) = -lon.(1);
end

% get range bins
radar_lat = 47.649793;
radar_lon = -122.312992;

ranges = zeros(1, numCollect);
bearings = zeros(1,numCollect);

for i = 1:numCollect
    [ranges(i),bearings(i)] = measure(radar_lat, radar_lon, lats(i), lons(i));
end
%Save ranges and bearings


% Haversine formula
function [d,b] = measure(lat1, lon1, lat2, lon2) 
    %Distance Calculations
    R = 6378.137; % Radius of earth in KM
    lat1 = lat1 * pi/180;
    lat2 = lat2 * pi/180;
    lon1 = lon1 * pi/180;
    lon2 = lon2 * pi/180;
    dLat = lat2 - lat1;
    dLon = lon2 - lon1;
    a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) ...
     * sin(dLon/2) * sin(dLon/2);
    c = 2 * atan2(sqrt(a), sqrt(1-a));
    d = R * c;
    d = d * 1000; % meters

    %Bearing
    b = atan2d(sin(dLon)*cos(lat2),cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon))-90;
    b = mod(b+360,360);
end

