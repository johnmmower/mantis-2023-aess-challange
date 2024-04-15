%% Read raw data file into a timetable
clc;
clear;

datetime.setDefaultFormats('default','yyyy-MM-dd HH:mm:ss.SSSSSSSSSSSS');
numFiles = 1968;        %Number of Collect Files
bufferSize = 49500;     %Buffer size per collect
fs = 25e6;              %Sample Rate (Hz)

% Save raw mat files to timetable
folderName = "20240328OceanographyTest/RVLeeThompsonSpin";
load(folderName+"/False0.mat");
%Initialize timetable (may be too large for preallocation)
datatt = array2timetable([complex_0',complex_1',complex_0'+complex_1',ones(size(complex_1')).*str2double(string_0(1,:))], ...
                                SampleRate=fs,VariableName={'LeftArrayRx','RightArrayRx','rx','SteerAngleDeg'},StartTime=datetime(string_0(2,:),Format='yyyy-MM-dd HH:mm:ss.SSSSSSSSS'));
for i=1:numFiles
    collect = load(folderName+"/False"+i+".mat");
    datatt = [datatt;array2timetable([collect.complex_0',collect.complex_1',collect.complex_0'+collect.complex_1',ones(size(collect.complex_0'))*str2double(collect.string_0(1,:))], ...
                    SampleRate=fs,VariableName={'LeftArrayRx','RightArrayRx','rx','SteerAngleDeg'},StartTime=datetime(collect.string_0(2,:),Format='yyyy-MM-dd HH:mm:ss.SSSSSSSSS'))];
end
%save datatt

% Save raw csv files to timetable
% i = 0;
% fileName = "20240413EdmondsTest/edmonds4/false"+i+".csv";
% data=readtable(fileName);
% beamSteer = data.Var2(2);
% 
% [cplxSignCell,numsCell]=regexp(data.Var2(4:end),'(?<=\d)[+-]','match','split');
% IQL = zeros(length(numsCell),1);
% 
% for j=1:length(numsCell)
%     if length(numsCell{j})<2
%         real = '0';
%         cplx = numsCell{j}{1,1}(1:end-1);
%     else
%         realCell = regexp(numsCell{j}{1,1},'\(','split');
%         real = cell2mat(realCell);
%         cplxCell = regexp(numsCell{j}{1,2},'\j)','split');
%         cplx = cell2mat([cplxSignCell{j},cplxCell]);
%     end
%     IQL(j)=complex(str2double(real),str2double(cplx));
% end
% 
% % [cplxSignCell,numsCell]=regexp(data.Var3(4:end),'(?<=\d)[+-]','match','split');
% [cplxSignCell,numsCell]=regexp(data.Var2(4:end),'(?<=\d)[+-]','match','split');
% IQR = zeros(length(numsCell),1);
% for j=1:length(numsCell)
%     if length(numsCell{j})<2
%         real = '0';
%         cplx = numsCell{j}{1,1}(1:end-1);
%     else
%         realCell = regexp(numsCell{j}{1,1},'\(','split');
%         real = cell2mat(realCell);
%         cplxCell = regexp(numsCell{j}{1,2},'\j)','split');
%         cplx = cell2mat([cplxSignCell{j},cplxCell]);
%     end
%     IQR(j)=complex(str2double(real),str2double(cplx));
% end
% 
% datatt = array2timetable([IQL,IQR,IQL+IQR,ones(size(numsCell))*str2double(cell2mat(beamSteer))],...
%     'StartTime',datetime(data.Var2(3),'InputFormat','yyyy-MM-dd HH:mm:ss.SSSSSS'),'SampleRate',fs, ...
%     'VariableNames', {'LeftArrayRx','RightArrayRx','rx','SteerAngleDeg'});
% 
% 
% 
% parfor i = 1:numFiles
%     fileName = "20240413EdmondsTest/edmonds4/false"+i+".csv";
%     data=readtable(fileName);
%     beamSteer = data.Var2(2);
% 
%     [cplxSignCell,numsCell]=regexp(data.Var2(4:end),'(?<=\d)[+-]','match','split');
%     IQL = zeros(length(numsCell),1);
% 
%     for j=1:length(numsCell)
%         if length(numsCell{j})<2
%             real = '0';
%             cplx = numsCell{j}{1,1}(1:end-1);
%         else
%             realCell = regexp(numsCell{j}{1,1},'\(','split');
%             real = cell2mat(realCell);
%             cplxCell = regexp(numsCell{j}{1,2},'\j)','split');
%             cplx = cell2mat([cplxSignCell{j},cplxCell]);
%         end
%         IQL(j)=complex(str2double(real),str2double(cplx));
%     end
% 
%     % [cplxSignCell,numsCell]=regexp(data.Var3(4:end),'(?<=\d)[+-]','match','split');
%     [cplxSignCell,numsCell]=regexp(data.Var2(4:end),'(?<=\d)[+-]','match','split');
%     IQR = zeros(length(numsCell),1);
%     for j=1:length(numsCell)
%         if length(numsCell{j})<2
%             real = '0';
%             cplx = numsCell{j}{1,1}(1:end-1);
%         else
%             realCell = regexp(numsCell{j}{1,1},'\(','split');
%             real = cell2mat(realCell);
%             cplxCell = regexp(numsCell{j}{1,2},'\j)','split');
%             cplx = cell2mat([cplxSignCell{j},cplxCell]);
%         end
%         IQR(j)=complex(str2double(real),str2double(cplx));
%     end
% 
%     datatt = [datatt; array2timetable([IQL,IQR,IQL+IQR,ones(size(numsCell))*str2double(cell2mat(beamSteer))], ...
%         'StartTime',datetime(data.Var2(3),'InputFormat','yyyy-MM-dd HH:mm:ss.SSSSSS'),'SampleRate',fs, ...
%         'VariableNames', {'LeftArrayRx','RightArrayRx','rx','SteerAngleDeg'})];
% end
% datatt = sortrows(datatt);
%save datatt
