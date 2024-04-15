import numpy as np
import adi
import pandas as pd
import time
import datetime as dt
import tkinter as tk

class PhaserRunner:
    def __init__(self, root, sdr_ip, rpi_ip) -> None:
        self.root = root
        self.root.title("FMCW Collect")

        self.sdr = None
        self.phaser = None
        self.sdr_ip = sdr_ip
        self.rpi_ip = rpi_ip
        
        self.do_go = False
        self.count = 0

        self.buffer_size = 2**17

        self.sample_rate = 25e6
        self.ramp_time = 600
        self.n_ramps = 3
        self.n_steps = self.ramp_time
        self.frame_length_ms = self.ramp_time * 1e-3 * self.n_ramps * (1.1) # 10% longer than we need for n cont. ramps
        
        self.folder = "./test"

        self.folder_label = tk.Label(root, text="folder name")
        self.folder_label.pack(pady=10)
        self.folder_input = tk.Entry(root, width=10)
        self.folder_input.insert(tk.END, str(self.folder))  # Default value for entry1
        self.folder_input.pack(pady=5)

        # Radio Buttons
        self.enable_steer_label = tk.Label(root, text="Enable beamsteer")
        self.enable_steer_label.pack(pady=10)
        self.steer_input = tk.BooleanVar()
        self.steer_input.set(False)  # Default selection
        
        self.radio_true = tk.Radiobutton(root, text="True", variable=self.steer_input, value=True)
        self.radio_true.pack()
        
        self.radio_false = tk.Radiobutton(root, text="False", variable=self.steer_input, value=False)
        self.radio_false.pack()

        # Button
        self.button = tk.Button(root, text="Go", command=self.on_button_click)
        self.button.pack(pady=5)

        self.button2 = tk.Button(root, text="Stop", command=self.stop)
        self.button2.pack(pady=5)
        
    def stop(self):
        #self.tdd_config()
        self.count = 0
        self.do_go = False

        self.sdr.tx_destroy_buffer()
        self.sdr.rx_destroy_buffer()

        self.sdr_pins.gpio_tdd_ext_sync = False
        self.sdr_pins.gpio_phaser_enable = False
    
        self.tdd.enable = False         # disable TDD to configure the registers
        self.tdd.sync_external = False
        self.tdd.channel[1].polarity = not(self.sdr_pins.gpio_phaser_enable)
        self.tdd.channel[2].polarity = self.sdr_pins.gpio_phaser_enable
        self.tdd.enable = True
        self.tdd.enable = False

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
        self.phaser._gpios.gpio_tx_sw = 0  # 0 = TX_OUT_2, 1 = TX_OUT_1
        self.phaser._gpios.gpio_vctrl_1 = 1  # 1=Use onboard PLL/LO source  (0=disable PLL and VCO, and set switch to use external LO input)
        self.phaser._gpios.gpio_vctrl_2 = (
            1  # 1=Send LO to transmit circuitry  (0=disable Tx path, and send LO to LO_OUT)
        )

        # Configure SDR Rx
        rxgain = 30
        center_freq = 2.15e9
        self.sdr.rx_lo = int(center_freq)  # set this to output_freq - (the freq of the HB100)
        #print(self.sdr.rx)
        self.sdr.rx_enabled_channels = [0, 1]  # enable Rx1 (voltage0) and Rx2 (voltage1)
        self.sdr.gain_control_mode_chan0 = "manual"  # manual or slow_attack
        self.sdr.gain_control_mode_chan1 = "manual"  # manual or slow_attack
        self.sdr.rx_hardwaregain_chan0 = int(rxgain)  # must be between -3 and 70
        self.sdr.rx_hardwaregain_chan1 = int(rxgain)  # must be between -3 and 70
        # Configure SDR Tx
        self.sdr.tx_lo = int(center_freq)
        self.sdr.tx_enabled_channels = [0, 1]
        self.sdr.tx_cyclic_buffer = True  # must set cyclic buffer to true for the tdd burst mode.  Otherwise Tx will turn on and off randomly
        self.sdr.tx_hardwaregain_chan0 = -88  # must be between 0 and -88
        self.sdr.tx_hardwaregain_chan1 = -0  # must be between 0 and -88

    def phaser_config(self):
        # Configure the ADF4159 Rampling PLL
        vco_freq = int(12.0e9)
        BW = 500e6
        num_steps = int(self.n_steps)    # in general it works best if there is 1 step per us
        self.phaser.frequency = int(vco_freq / 4)
        self.phaser.freq_dev_range = int(BW / 4)      # total freq deviation of the complete freq ramp in Hz
        self.phaser.freq_dev_step = int((BW / 4) / num_steps)  # This is fDEV, in Hz.  Can be positive or negative
        self.phaser.freq_dev_time = int(self.ramp_time)  # total time (in us) of the complete frequency ramp
        print("requested freq dev time = ", self.ramp_time)
        print("actual freq dev time = ", self.phaser.freq_dev_time)
        self.phaser.delay_word = 4095  # 12 bit delay word.  4095*PFD = 40.95 us.  For sawtooth ramps, this is also the length of the Ramp_complete signal
        self.phaser.delay_clk = "PFD"  # can be 'PFD' or 'PFD*CLK1'
        self.phaser.delay_start_en = 0  # delay start
        self.phaser.ramp_delay_en = 0  # delay between ramps.
        self.phaser.trig_delay_en = 0  # triangle delay
        self.phaser.ramp_mode = "continuous_sawtooth"  # ramp_mode can be:  "disabled", "continuous_sawtooth", "continuous_triangular", "single_sawtooth_burst", "single_ramp_burst"
        self.phaser.sing_ful_tri = 0  # full triangle enable/disable -- this is used with the single_ramp_burst mode
        self.phaser.tx_trig_en = 1  # start a ramp with TXdata
        self.phaser.enable = 0  # 0 = PLL enable.  Write this last to update all the registers

    def tdd_config(self):
        # %%
        """ Synchronize chirps to the start of each Pluto receive buffer
        """
        # Configure TDD controller
        sdr_pins = adi.one_bit_adc_dac(self.sdr_ip)
        sdr_pins.gpio_tdd_ext_sync = True # If set to True, this enables external capture triggering using the L24N GPIO on the Pluto.  When set to false, an internal trigger pulse will be generated every second
        tdd = adi.tddn(self.sdr_ip)
        sdr_pins.gpio_phaser_enable = True
        self.sdr_pins = sdr_pins
        tdd.enable = False         # disable TDD to configure the registers
        tdd.sync_external = True
        tdd.startup_delay_ms = 0
        tdd.frame_length_ms = self.frame_length_ms
        num_chirps = 1
        tdd.burst_count = num_chirps       # number of bursts to do in cont. ramp modes, number of chirps in single modes

        tdd.channel[0].enable = True
        tdd.channel[0].polarity = False
        tdd.channel[0].on_ms = 0.01
        tdd.channel[0].off_ms = 0.1
        tdd.channel[1].enable = True
        tdd.channel[1].polarity = False
        tdd.channel[1].on_ms = 0.1
        tdd.channel[1].off_ms = 0.2
        tdd.channel[2].enable = False
        tdd.enable = True

        self.tdd = tdd


    def sdr_config(self):
        sample_rate = self.sample_rate
        signal_freq = 5e5

        num_slices = 400
        self.buffer_size = int(self.frame_length_ms*(1e-3)*sample_rate)
        #self.buffer_size = 2 ** int(np.ceil(np.log2(self.frame_length_ms*(1e-3)*sample_rate))) # round up to next power of 2 buffer size
        #self.buffer_size = 2 ** (int(np.log2(self.sample_rate/1e6 * self.ramp_time * self.n_ramps)) + 1)
        #self.buffer_size = 2 ** 19
        fft_size = int(self.buffer_size)
        img_array = np.ones((num_slices, fft_size)) * (-100)

        self.sdr.sample_rate = int(sample_rate)
        self.sdr.rx_buffer_size = int(fft_size)

        #N = int(self.sdr.rx_buffer_size)
        N = int(signal_freq / 100)
        fc = int(signal_freq)
        ts = 1 / float(sample_rate)
        t = np.arange(0, N * ts, ts)
        i = np.cos(2 * np.pi * t * fc) * 2 ** 14
        q = np.sin(2 * np.pi * t * fc) * 2 ** 14
        iq = 1 * (i + 1j * q)

        # transmit data from Pluto
        self.sdr._ctx.set_timeout(30000) # wait 30 seconds to get your receive
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
        steer = self.steer_input.get()
        angles = np.linspace(-10, 10, 5)

        if self.do_go:
            if steer:
                for i in range(len(angles)):
                        time.sleep(5e-3) # 5ms
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
                        self.capture(info, steer)
                        self.count += 1
            else:
                '''
                if you get hella problems with broken pipes here, its
                probs because your ethernet cable is bad :(
                '''
                self.phaser.set_beam_phase_diff(0)
                info = [0, dt.datetime.now()]
                self.capture(info, steer)
                self.count += 1
            self.root.after(0, self.run)

    def on_button_click(self):
        try:
            self.hardware_init(self.sdr_ip, self.rpi_ip)
            self.folder = str(self.folder_input.get())
        except ValueError:
            self.result_label.config(text="Bad inputs")

        self.phaser_config()
        self.tdd_config()
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
    app = PhaserRunner(root, sdr_ip, rpi_ip)
    root.mainloop()

if __name__ == "__main__":
    main()