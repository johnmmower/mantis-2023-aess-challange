import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat
from scipy.fft import fft, fftfreq, fftshift

n_snapshots = 1
for i in range(0, n_snapshots):
    mat = loadmat('mats/RVLEETHOMPSON/False'+str(i)+'.mat')

    rx_ch0 = mat['complex_0']
    rx_ch1 = mat['complex_1']

    fs = 25e6

    data = rx_ch0[0,:] + rx_ch1[0,:]
    unwrapped_data = np.diff(np.unwrap(np.angle(data)))
    t = np.arange(0, len(unwrapped_data) / fs, 1/fs)

    plt.figure(0)
    plt.plot(t, unwrapped_data, label='demod data' + str(i))
    plt.figure(1)
    t = np.arange(0, len(data) / fs, 1/fs)
    plt.plot(t, data, label='modulated data ' + str(i))

plt.figure(0)
plt.ylabel('diff(unwrap(phase)) (radians)')
plt.xlabel('time (s)')
#plt.legend()
plt.show()