import re
import sys
import time
from time import perf_counter_ns
import threading
import serial
import serial.tools.list_ports

class SerialConnection:
    """Responsible for communication via serial"""
    __serial = None
    __stop_threads = False  # flag to control the threads
    response_count = 0
    t0 = 0

    def __init__(self) -> None:
        """Initialize the serial connection to the microcontroller"""
        self.__serial_connection()
        print("Serial communication initialized")
        self.start_threads()
        self.send_delay = 0.02

    def __serial_connection(self) -> bool:
        """Makes the connection with the microcontroller"""
        try:
            ports = serial.tools.list_ports.comports()
            if not ports:
                print("No COM ports available.")
                raise IndexError
            if self.__serial is None:
                print("Available COM ports: " + str(ports))
                ports = sorted(ports)
                selected_port = None
                if "win" in sys.platform:
                    for port, desc, hwid in ports:
                        if ("USB Serial Port" in desc):
                            selected_port = port
                            break                  
                else:
                    for port, desc, hwid in ports:
                        if "ttyACM" in desc:
                            selected_port = port
                            break
                print("Selected microcontroller COM port: " + str(selected_port))
                self.__serial = serial.Serial(selected_port, 9600, timeout=0.1,
                                              stopbits=serial.STOPBITS_ONE, bytesize=serial.EIGHTBITS)
                time.sleep(3)
            if not self.__serial.is_open:
                self.__serial.open()
                time.sleep(3)
            if not self.__serial.is_open:
                raise IndexError
            else:
                return True
        except Exception as e:
            print(e)
            print("Connection to microcontroller failed. Trying again in 5 seconds.")
            time.sleep(5)
            self.__serial = None
            return self.__serial_connection() 

    def send_message(self, command: int) -> None:
        """Send a message via serial"""
        if self.__serial_connection():
            self.__serial.write(command)
            time.sleep(self.send_delay)

    def read_message(self) -> None:
        """Receive a message via serial"""
        if self.__serial_connection():
            try:
                while not self.__stop_threads:
                    char = self.__serial.read(1)  # read one byte at a time
                    if char:
                        print("Received:", char.decode(errors='ignore'), hex(char[0]), flush=True)
                        
                        if (char[0] == 0x05):
                            self.response_count = self.response_count + 1
                            print(f"Response count: {self.response_count}")
                            if self.response_count == 10:
                                t1 = perf_counter_ns()
                                elapsed_time = t1 - self.t0
                                print(f"Executed 10 instructions in {elapsed_time} ns ({elapsed_time/1_000_000} ms)")
                        
                        # time.sleep(self.send_delay/2)
                        # self.__serial.flushInput()
            except serial.SerialException as e:
                print("Serial exception:", e)

    def start_threads(self):
        """Starts the threads for reading and writing"""
        self.__stop_threads = False
        self.write_thread = threading.Thread(target=self.write_loop)
        self.read_thread = threading.Thread(target=self.read_message)

        # Start both threads
        self.write_thread.start()
        self.read_thread.start()
        

    def write_loop(self):
        """Continuously prompt for user input to send to the serial port"""
        
        send_count = 0
        
        while not self.__stop_threads:
            command = input("Enter a command to send (or 'exit' to close): ")
            if command.lower() == 'exit':
                self.close_serial()  # Close the serial and stop the program
                break
            
            if send_count == 0:
                self.send_message(b'\xA5')
            elif send_count == 1:
                self.send_message(b'\xA6')
            elif send_count == 2:
                self.send_message(b'\x00')
            elif send_count == 3:
                self.send_message(b'\x00')
            elif send_count == 4:
                self.send_message(b'\xAB')
            elif send_count == 5:
                self.send_message(b'\xCD')
            elif send_count == 6:
                self.send_message(b'\x7A')

    def close_serial(self) -> None:
        """Close serial connection and stop threads"""
        self.__stop_threads = True  # signal threads to stop
        if self.__serial:
            self.__serial.close()
        print("Serial closed")

# Usage
serial_connection = SerialConnection()
