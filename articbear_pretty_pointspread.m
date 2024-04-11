clc;clear all;close all

N = 458;
Nd = 12830;

data = zeros(N,Nd);
tims = zeros(1,N);

for i = 0:N-1

display(i)
load(sprintf('data/False%d.mat', i))
d = complex_0 + complex_1;

s = split(string_0(2,:));
s = split(s{2},':');
tims(i+1) = str2num(s{1})*60*60+str2num(s{2})*60+str2num(s{3});

a = d(1:15025);
b = d(15026:30050);
c = d(30051:45075);

a = a(1:Nd);
b = b(1:Nd);
c = c(1:Nd);

a = a.*transpose(hamming(length(a)));
b = b.*transpose(hamming(length(b)));
c = c.*transpose(hamming(length(c)));

A = fft(a);
B = fft(b);
C = fft(c);

ap = mean(angle(A(259))); %256:262
bp = mean(angle(B(259)));
cp = mean(angle(C(259)));

A = A * exp(-1j*ap);
B = B * exp(-1j*bp);
C = C * exp(-1j*cp);

data(i+1,:) = A+B+C;

end

MLIM = 3.2;
MMAX = 4.5;

tims = tims-min(tims);

DATA = log10(abs(data));
[val,idx] = max(DATA(1,:))
DATA = DATA(:,idx:idx+1200);

fs = 25e6;
df = fs/15025;
dr = 3e8*df*600e-6/(2*500e6);
r = dr*(0:1:length(DATA(1,:))-1);


DDATA = DATA(:,350:420);
rr = r(350:420);

[R,T] = meshgrid(rr,tims);
rri = linspace(rr(1),rr(end),500);
[RR,TR] = meshgrid(rri,tims);

DDATAR = interp2(R,T,DDATA,RR,TR);
DDATAR(DDATAR < MLIM) = MLIM;
DDATAR(DDATAR > MMAX) = MMAX;

imagesc(rri,tims,DDATAR)
axis([rri(1) rri(end) 7 38])

xlabel('range [m]')
ylabel('time [s]')
