import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat, savemat
from scipy.fft import fft, fftfreq, fftshift
import pandas as pd
import datetime

t0 = ''
tn = ''

n_snapshots = 400
waterfall_array = np.ones((n_snapshots, 49500))
complex_waterfall_array = np.ones((n_snapshots, 49500), dtype=np.complex128)
for i in range(0, n_snapshots):
    mat = loadmat('mats/arctic_fox/False'+str(i)+'.mat')

    if i == 0:
        t0 = datetime.datetime.strptime(mat['string_0'][1], '%Y-%m-%d %H:%M:%S.%f')
    elif i == n_snapshots-1:
        tn = datetime.datetime.strptime(mat['string_0'][1], '%Y-%m-%d %H:%M:%S.%f')

    rx_ch0 = mat['complex_0']
    rx_ch1 = mat['complex_1']

    fs = 25e6

    data = rx_ch0[0,:] + rx_ch1[0,:]

    fft_rx = fftshift(fft(data))
    f = np.linspace(-fs/2, fs/2, len(fft_rx), endpoint=True)

    complex_waterfall_array[i] = fft_rx
    waterfall_array[i] = 10 * np.log10(np.abs(fft_rx))

    plt.figure(0)
    if i > 240 and i < 250:
        plt.plot(f, 10 * np.log10(np.abs(fft_rx)), label='snapshot' + str(i))

#plt.legend()
savemat('waterfall_arctic_fox.mat', {'data': complex_waterfall_array})
# array to set colorbar bounds
img_array = np.ones((n_snapshots, int(25e3))) * 45
img_array[0,0] = 30

fig = plt.figure(1)
ax = fig.add_subplot(1,1,1)
im = ax.imshow(img_array.T, aspect='auto', extent=[0,(int(tn.strftime('%s'))-int(t0.strftime('%s'))),-fs/2,fs/2])
fig.colorbar(im)
im.set_data(np.flip(waterfall_array.T, axis=0))
ax.set_ylabel('frequency (Hz)')
ax.set_xlabel('time (s)')
fig.show()
plt.show()