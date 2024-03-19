# Copyright (C) 2023 Analog Devices, Inc.
#
# SPDX short identifier: ADIBSD
import time
import datetime as dt
import pandas as pd
import adi
import numpy as np
import tkinter as tk

class RunContext:
    def __enter__(self):
        pass
    
    def __exit__(self, exc_type, exc_value, traceback):
        # Return True to suppress any exception that occurred within the context
        return True

class MyApp:
    def __init__(self, root, sdr_ip, rpi_ip):
        self.root = root
        self.root.title("FMCW Collect")

        self.do_go = False
        self.count = 0

        self.buffer_size = 2**17

        self.sample_rate = 24
        self.ramp_time = 600
        self.n_ramps = 3
        self.n_steps = self.ramp_time
        self.frame_length_ms = 0

        self.folder = "./Commons"
        
        # Label
        self.sr_label = tk.Label(root, text="Sample Rate (Msps)")
        self.sr_label.pack(pady=10)
        
        # Input Boxes
        self.sample_rate_input = tk.Entry(root, width=10)
        self.sample_rate_input.insert(tk.END, str(self.sample_rate))  # Default value for entry1
        self.sample_rate_input.pack(pady=5)
        
        self.rt_label = tk.Label(root, text="Ramp Time")
        self.rt_label.pack(pady=10)
        self.ramp_time_input = tk.Entry(root, width=10)
        self.ramp_time_input.insert(tk.END, str(self.ramp_time))  # Default value for entry1
        self.ramp_time_input.pack(pady=5)

        self.n_ramp_label = tk.Label(root, text="Ramps Per RX")
        self.n_ramp_label.pack(pady=10)
        self.n_ramps_input = tk.Entry(root, width=10)
        self.n_ramps_input.insert(tk.END, str(self.n_ramps))  # Default value for entry1
        self.n_ramps_input.pack(pady=5)

        self.n_steps_label = tk.Label(root, text="f_dev steps")
        self.n_steps_label.pack(pady=10)
        self.n_steps_input = tk.Entry(root, width=10)
        self.n_steps_input.insert(tk.END, str(self.n_steps))  # Default value for entry1
        self.n_steps_input.pack(pady=5)

        self.folder_label = tk.Label(root, text="folder name")
        self.folder_label.pack(pady=10)
        self.folder_input = tk.Entry(root, width=10)
        self.folder_input.insert(tk.END, str(self.folder))  # Default value for entry1
        self.folder_input.pack(pady=5)

        # Radio Buttons
        self.enable_sweep_label = tk.Label(root, text="Enable sweep")
        self.enable_sweep_label.pack(pady=10)
        self.look_sweep = tk.BooleanVar()
        self.look_sweep.set(False)  # Default selection
        
        self.radio_true = tk.Radiobutton(root, text="True", variable=self.look_sweep, value=True)
        self.radio_true.pack()
        
        self.radio_false = tk.Radiobutton(root, text="False", variable=self.look_sweep, value=False)
        self.radio_false.pack()

        # Button
        self.button = tk.Button(root, text="Go", command=self.on_button_click)
        self.button.pack(pady=5)

        self.button2 = tk.Button(root, text="Stop", command=self.stop)
        self.button2.pack(pady=5)
        
        # Result Label
        self.result_label = tk.Label(root, text="")
        self.result_label.pack(pady=10)

        self.sdr = None
        self.phaser = None
        self.sdr_ip = sdr_ip
        self.rpi_ip = rpi_ip

    def stop(self):
        self.count = 0
        self.do_go = False


    def hardware_init(self, sdr_ip, rpi_ip):
        '''
        Init fixed params of hardware; stuff that doesn't change based on user input
        '''
        # Instantiate all the Devices
        self.sdr = adi.ad9361(uri=sdr_ip)
        self.phaser = adi.CN0566(uri=rpi_ip)

        # Initialize both ADAR1000s, set gains to max, and all phases to 0
        self.phaser.configure(device_mode="rx")
        self.phaser.element_spacing = 0.014
        self.phaser.load_gain_cal()
        self.phaser.load_phase_cal()
        for i in range(0, 8):
            self.phaser.set_chan_phase(i, 0)

        gain_list = [8, 34, 84, 127, 127, 84, 34, 8]  # Blackman taper
        for i in range(0, len(gain_list)):
            self.phaser.set_chan_gain(i, gain_list[i], apply_cal=True)

        # Setup Raspberry Pi GPIO states
        try:
            self.phaser._gpios.gpio_tx_sw = 0  # 0 = TX_OUT_2, 1 = TX_OUT_1
            self.phaser._gpios.gpio_vctrl_1 = 1  # 1=Use onboard PLL/LO source  (0=disable PLL and VCO, and set switch to use external LO input)
            self.phaser._gpios.gpio_vctrl_2 = (
                1  # 1=Send LO to transmit circuitry  (0=disable Tx path, and send LO to LO_OUT)
            )
        except:
            self.phaser.gpios.gpio_tx_sw = 0  # 0 = TX_OUT_2, 1 = TX_OUT_1
            self.phaser.gpios.gpio_vctrl_1 = 1  # 1=Use onboard PLL/LO source  (0=disable PLL and VCO, and set switch to use external LO input)
            self.phaser.gpios.gpio_vctrl_2 = (
                1  # 1=Send LO to transmit circuitry  (0=disable Tx path, and send LO to LO_OUT)
            )

        # Configure SDR Rx
        center_freq = 1.6e9
        self.sdr.rx_lo = int(center_freq)  # set this to output_freq - (the freq of the HB100)
        print(self.sdr.rx)
        self.sdr.rx_enabled_channels = [0, 1]  # enable Rx1 (voltage0) and Rx2 (voltage1)
        self.sdr.gain_control_mode_chan0 = "manual"  # manual or slow_attack
        self.sdr.gain_control_mode_chan1 = "manual"  # manual or slow_attack
        self.sdr.rx_hardwaregain_chan0 = int(20)  # must be between -3 and 70
        self.sdr.rx_hardwaregain_chan1 = int(20)  # must be between -3 and 70
        # Configure SDR Tx
        self.sdr.tx_lo = int(center_freq)
        self.sdr.tx_enabled_channels = [0, 1]
        self.sdr.tx_cyclic_buffer = True  # must set cyclic buffer to true for the tdd burst mode.  Otherwise Tx will turn on and off randomly
        self.sdr.tx_hardwaregain_chan0 = -88  # must be between 0 and -88
        self.sdr.tx_hardwaregain_chan1 = -0  # must be between 0 and -88

    def phaser_config(self):
        # Configure the ADF4159 Rampling PLL
        vco_freq = int(11.6e9)
        BW = 500e6
        num_steps = int(self.n_steps)    # in general it works best if there is 1 step per us
        self.phaser.frequency = int(vco_freq / 4)
        self.phaser.freq_dev_range = int(BW / 4)      # total freq deviation of the complete freq ramp in Hz
        self.phaser.freq_dev_step = int((BW / 4) / num_steps)  # This is fDEV, in Hz.  Can be positive or negative
        self.phaser.freq_dev_time = int(self.ramp_time)  # total time (in us) of the complete frequency ramp
        print("requested freq dev time = ", self.ramp_time)
        self.phaser.delay_word = 4095  # 12 bit delay word.  4095*PFD = 40.95 us.  For sawtooth ramps, this is also the length of the Ramp_complete signal
        self.phaser.delay_clk = "PFD"  # can be 'PFD' or 'PFD*CLK1'
        self.phaser.delay_start_en = 0  # delay start
        self.phaser.ramp_delay_en = 0  # delay between ramps.
        self.phaser.trig_delay_en = 0  # triangle delay
        self.phaser.ramp_mode = "single_sawtooth_burst"  # ramp_mode can be:  "disabled", "continuous_sawtooth", "continuous_triangular", "single_sawtooth_burst", "single_ramp_burst"
        self.phaser.sing_ful_tri = 0  # full triangle enable/disable -- this is used with the single_ramp_burst mode
        self.phaser.tx_trig_en = 1  # start a ramp with TXdata
        self.phaser.enable = 0  # 0 = PLL enable.  Write this last to update all the registers

        self.tdd_config()

    def tdd_config(self):
        # %%
        """ Synchronize chirps to the start of each Pluto receive buffer
        """
        # Configure TDD controller
        sdr_pins = adi.one_bit_adc_dac(self.sdr_ip)
        sdr_pins.gpio_tdd_ext_sync = True # If set to True, this enables external capture triggering using the L24N GPIO on the Pluto.  When set to false, an internal trigger pulse will be generated every second
        tdd = adi.tddn(self.sdr_ip)
        sdr_pins.gpio_phaser_enable = True
        tdd.enable = False         # disable TDD to configure the registers
        tdd.sync_external = True
        tdd.startup_delay_ms = 0
        tdd.frame_length_ms = self.phaser.freq_dev_time/1e3 + 1.2    # each chirp is spaced this far apart
        self.frame_length_ms = tdd.frame_length_ms
        num_chirps = self.n_ramps
        tdd.burst_count = num_chirps       # number of chirps in one continuous receive buffer

        tdd.out_channel0_enable = True
        tdd.out_channel0_polarity = False
        tdd.out_channel0_on_ms = 0.02
        tdd.out_channel0_off_ms = 0.03
        tdd.out_channel1_enable = True
        tdd.out_channel1_polarity = False
        tdd.out_channel1_on_ms = 0.02
        tdd.out_channel1_off_ms = 0.03
        tdd.out_channel2_enable = True
        tdd.out_channel2_on_ms = 0.01
        tdd.out_channel2_off_ms = 0.02
        tdd.enable = True


    def sdr_config(self):
        sample_rate = self.sample_rate
        signal_freq = 5e5

        num_slices = 400
        self.buffer_size = 2 ** (int(np.log2(self.frame_length_ms*(1e-3)*self.sample_rate*self.n_ramps)) + 1)
        #self.buffer_size = 2 ** (int(np.log2(self.sample_rate/1e6 * self.ramp_time * self.n_ramps)) + 1)
        fft_size = int(self.buffer_size)
        img_array = np.ones((num_slices, fft_size)) * (-100)

        self.sdr.sample_rate = int(sample_rate)
        self.sdr.rx_buffer_size = int(fft_size)

        N = int(self.buffer_size)
        fc = int(signal_freq)
        ts = 1 / float(sample_rate)
        t = np.arange(0, N * ts, ts)
        i = np.cos(2 * np.pi * t * fc) * 2 ** 14
        q = np.sin(2 * np.pi * t * fc) * 2 ** 14
        iq = 1 * (i + 1j * q)

        # transmit data from Pluto
        self.sdr._ctx.set_timeout(30000)
        self.sdr._rx_init_channels()
        self.sdr.tx([iq, iq])

    def capture(self, info, look_sweep):
        self.phaser._gpios.gpio_burst = 0
        self.phaser._gpios.gpio_burst = 1
        self.phaser._gpios.gpio_burst = 0
        data = np.array(self.sdr.rx())

        stamped = pd.DataFrame(info)
        stamped = pd.concat([stamped, pd.DataFrame(data.T)])
        stamped.to_csv(str(self.folder) + '/' + str(look_sweep) + str(self.count) + '.csv', sep=',')

    def run(self):
        look_sweep = self.look_sweep.get()
        angles = np.linspace(-90, 90, 21)
        if look_sweep:
            for i in range(len(angles)):
                    time.sleep(2e-3) # 2ms
                    phase_delta = (
                        2
                        * 3.14159
                        * 10.25e9
                        * 0.014
                        * np.sin(np.radians(angles[i]))
                        / (3e8)
                    )
                    self.phaser.set_beam_phase_diff(np.degrees(phase_delta))
                    info = [angles[i], dt.datetime.now()]
                    self.capture(info, look_sweep)
                    self.count += 1
        else:
            '''
            if you get hella problems with broken pipes here, its
            probs because your ethernet cable is bad :(
            '''
            self.phaser.set_beam_phase_diff(0)
            info = [0, dt.datetime.now()]
            self.capture(info, look_sweep)
            self.count += 1
        if self.do_go:
            self.root.after(0, self.run)

    def on_button_click(self):
        try:
            self.hardware_init(self.sdr_ip, self.rpi_ip)
            self.sample_rate = int(self.sample_rate_input.get()) * 1e6
            self.ramp_time = int(self.ramp_time_input.get())
            self.n_ramps = int(self.n_ramps_input.get())
            self.n_steps = int(self.n_steps_input.get())
            self.folder = str(self.folder_input.get())
        except ValueError:
            self.result_label.config(text="Bad inputs, integers only")

        self.phaser_config()
        self.sdr_config()
        
        print(
            """
        CONFIG:
        Sample rate: {sample_rate}MHz
        Num samples: 2^{Nlog2}
        Ramp time: {ramp_time}ms
        """.format(
                sample_rate=self.sample_rate / 1e6,
                Nlog2=int(np.log2(self.sdr.rx_buffer_size)),
                ramp_time=self.ramp_time / 1e3)
        )

        self.do_go = True
        self.run()

def main():
    # off by 10kHz
    rpi_ip = "ip:phaser.local"  # IP address of the Raspberry Pi
    sdr_ip = "ip:192.168.2.1"  # "192.168.2.1, or pluto.local"  # IP address of the Transceiver Block
    root = tk.Tk()
    app = MyApp(root, sdr_ip, rpi_ip)
    root.mainloop()

if __name__ == "__main__":
    main()


