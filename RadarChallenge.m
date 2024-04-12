%% Read File
clc;
clear;

datetime.setDefaultFormats('default','yyyy-MM-dd HH:mm:ss.SSSSSSSSSSSS');
numFiles = 1968;
fs = 25e6;


i = 0;
fileName = "20240328OceanographyTest/RVLeeThompsonSpin/false"+i+".csv";
data=readtable(fileName);
beamSteer = data.Var2(2);

[cplxSignCell,numsCell]=regexp(data.Var2(4:end),'(?<=\d)[+-]','match','split');
IQL = zeros(length(numsCell),1);

for j=1:length(numsCell)
    if length(numsCell{j})<2
        real = '0';
        cplx = numsCell{j}{1,1}(1:end-1);
    else
        realCell = regexp(numsCell{j}{1,1},'\(','split');
        real = cell2mat(realCell);
        cplxCell = regexp(numsCell{j}{1,2},'\j)','split');
        cplx = cell2mat([cplxSignCell{j},cplxCell]);
    end
    IQL(j)=complex(str2double(real),str2double(cplx));
end

% [cplxSignCell,numsCell]=regexp(data.Var3(4:end),'(?<=\d)[+-]','match','split');
[cplxSignCell,numsCell]=regexp(data.Var2(4:end),'(?<=\d)[+-]','match','split');
IQR = zeros(length(numsCell),1);
for j=1:length(numsCell)
    if length(numsCell{j})<2
        real = '0';
        cplx = numsCell{j}{1,1}(1:end-1);
    else
        realCell = regexp(numsCell{j}{1,1},'\(','split');
        real = cell2mat(realCell);
        cplxCell = regexp(numsCell{j}{1,2},'\j)','split');
        cplx = cell2mat([cplxSignCell{j},cplxCell]);
    end
    IQR(j)=complex(str2double(real),str2double(cplx));
end

datatt = array2timetable([IQL,IQR,IQL+IQR,ones(size(numsCell))*str2double(cell2mat(beamSteer))],...
    'StartTime',datetime(data.Var2(3),'InputFormat','yyyy-MM-dd HH:mm:ss.SSSSSS'),'SampleRate',fs, ...
    'VariableNames', {'LeftArrayRx','RightArrayRx','rx','SteerAngleDeg'});



parfor i = 1:numFiles
    fileName = "20240328OceanographyTest/RVLeeThompsonSpin/false"+i+".csv";
    data=readtable(fileName);
    beamSteer = data.Var2(2);

    [cplxSignCell,numsCell]=regexp(data.Var2(4:end),'(?<=\d)[+-]','match','split');
    IQL = zeros(length(numsCell),1);

    for j=1:length(numsCell)
        if length(numsCell{j})<2
            real = '0';
            cplx = numsCell{j}{1,1}(1:end-1);
        else
            realCell = regexp(numsCell{j}{1,1},'\(','split');
            real = cell2mat(realCell);
            cplxCell = regexp(numsCell{j}{1,2},'\j)','split');
            cplx = cell2mat([cplxSignCell{j},cplxCell]);
        end
        IQL(j)=complex(str2double(real),str2double(cplx));
    end

    % [cplxSignCell,numsCell]=regexp(data.Var3(4:end),'(?<=\d)[+-]','match','split');
    [cplxSignCell,numsCell]=regexp(data.Var2(4:end),'(?<=\d)[+-]','match','split');
    IQR = zeros(length(numsCell),1);
    for j=1:length(numsCell)
        if length(numsCell{j})<2
            real = '0';
            cplx = numsCell{j}{1,1}(1:end-1);
        else
            realCell = regexp(numsCell{j}{1,1},'\(','split');
            real = cell2mat(realCell);
            cplxCell = regexp(numsCell{j}{1,2},'\j)','split');
            cplx = cell2mat([cplxSignCell{j},cplxCell]);
        end
        IQR(j)=complex(str2double(real),str2double(cplx));
    end

    datatt = [datatt; array2timetable([IQL,IQR,IQL+IQR,ones(size(numsCell))*str2double(cell2mat(beamSteer))], ...
        'StartTime',datetime(data.Var2(3),'InputFormat','yyyy-MM-dd HH:mm:ss.SSSSSS'),'SampleRate',fs, ...
        'VariableNames', {'LeftArrayRx','RightArrayRx','rx','SteerAngleDeg'})];
end
datatt = sortrows(datatt);