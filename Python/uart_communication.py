import re
import sys
import time
import threading
import serial
import serial.tools.list_ports

class SerialConnection:
    """Responsible for communication via serial"""
    __serial = None
    __stop_threads = False  # flag to control the threads

    def __init__(self) -> None:
        """Initialize the serial connection to the microcontroller"""
        self.__serial_connection()
        print("Serial communication initialized")
        self.start_threads()

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
                    selected_port = ports[0][0]
                else:
                    for port, desc, hwid in ports:
                        if "ttyACM" in desc:
                            selected_port = port
                            break
                print("Selected microcontroller COM port: " + str(selected_port))
                self.__serial = serial.Serial(selected_port, 9600, timeout=1,
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

    def send_message(self, command: str) -> None:
        """Send a message via serial"""
        if self.__serial_connection():
            self.__serial.write(command.encode())

    def read_message(self) -> None:
        """Receive a message via serial"""
        if self.__serial_connection():
            try:
                while not self.__stop_threads:
                    char = self.__serial.read(1)  # read one byte at a time
                    if char:
                        print("Received:", char.decode(errors='ignore'), flush=True)
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
        while not self.__stop_threads:
            command = input("Enter a command to send (or 'exit' to close): ")
            if command.lower() == 'exit':
                self.close_serial()  # Close the serial and stop the program
                break
            self.send_message(command)

    def close_serial(self) -> None:
        """Close serial connection and stop threads"""
        self.__stop_threads = True  # signal threads to stop
        if self.__serial:
            self.__serial.close()
        print("Serial closed")

# Usage
serial_connection = SerialConnection()
