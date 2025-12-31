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
        
    def send_instruction(
        self,
        opcode, oparg_type, oparg,
        argval_type, argval,
        *,
        byteorder="big",
        argval_size=4,     # <— força 4 bytes por padrão
        signed=False       # se um dia precisar de negativos
    ):
        def _one_byte(x, name):
            if isinstance(x, int):
                if not (0 <= x <= 0xFF): raise ValueError(f"{name} fora de 0..255")
                return bytes([x])
            if isinstance(x, (bytes, bytearray)) and len(x) == 1:
                return bytes(x)
            raise TypeError(f"{name} deve ser int(0..255) ou bytes(1)")

        def _two_bytes(x, name):
            if isinstance(x, int):
                if not (0 <= x <= 0xFFFF): raise ValueError(f"{name} fora de 0..65535")
                return x.to_bytes(2, byteorder, signed=False)
            if isinstance(x, (bytes, bytearray)) and len(x) == 2:
                return bytes(x)
            raise TypeError(f"{name} deve ser int(0..65535) ou bytes(2)")

        def _argval_bytes(x, size, name):
            if isinstance(x, int):
                # valida se cabe no tamanho solicitado
                minv = -(1 << (8*size - 1)) if signed else 0
                maxv =  (1 << (8*size - 1)) - 1 if signed else (1 << (8*size)) - 1
                if not (minv <= x <= maxv):
                    raise ValueError(f"{name} não cabe em {size} bytes (signed={signed})")
                return x.to_bytes(size, byteorder, signed=signed)
            if isinstance(x, (bytes, bytearray)):
                b = bytes(x)
                if size is None:
                    return b
                if len(b) > size:
                    raise ValueError(f"{name} tem {len(b)} bytes, maior que {size}")
                # pad à esquerda para big-endian, à direita para little-endian
                pad = bytes(size - len(b))
                return (pad + b) if byteorder == "big" else (b + pad)
            raise TypeError(f"{name} deve ser int ou bytes")

        payload = bytearray()
        payload += _one_byte(opcode, "opcode")
        payload += _one_byte(oparg_type, "arg_type")
        payload += _two_bytes(oparg, "arg")

        payload += _one_byte(argval_type, "argval_type")

        # se quiser “tamanho automático”, passe argval_size=None
        size = len(argval) if (isinstance(argval, (bytes, bytearray)) and argval_size is None) else (argval_size or 1)
        arg_val_b = _argval_bytes(argval, size, "arg_val")

        if len(arg_val_b) > 255:
            raise ValueError("arg_val maior que 255 bytes")
        payload += bytes([len(arg_val_b)])
        payload += arg_val_b

        self.send_message(bytes(payload))

        
    def test_vm(self):           
        # Send resume
        input("continue?")
        self.send_instruction(0x97, 0x01, 0x0000, 0x01, 0x00000000, byteorder="big")
        
        # Send load_name print
        input("continue?")
        self.send_instruction(0x65, 0x01, 0x0000, 0x05, 0x00000001, byteorder="big")
        
        # Send load_const
        input("continue?")
        self.send_instruction(0x64, 0x01, 0x0001, 0x01, 0x00000003, byteorder="big")
        
        # Send load_const
        input("continue?")
        self.send_instruction(0x64, 0x01, 0x0002, 0x01, 0x00000006, byteorder="big")
        
        # Send binary_op
        input("continue?")
        self.send_instruction(0x7A, 0x01, 0x0000, 0x01, 0x0000000A, byteorder="big")
        
        # Send call
        input("continue?")
        self.send_instruction(0xAB, 0x01, 0x0001, 0x01, 0x00000001, byteorder="big")
        
    def execute_op(self, interrupt=False):
        self.response_count = 0
        self.t0 = perf_counter_ns()

        #opcode, oparg_type, oparg, argval_type, argval

        # 1 Send resume
        if interrupt:
            input("send resume?")
        self.send_instruction(0x97, 0x01, 0x0000, 0x01, 0x00000000, byteorder="big")
        
        # 2 Send load_const
        if interrupt:
            input("send load const 1?")                 #B
        self.send_instruction(0x64, 0x01, 0x0001, 0x01, 0x55555555, byteorder="big")
        
        # 3 Send load_const
        if interrupt:
            input("send load const 2?")                 #A
        self.send_instruction(0x64, 0x01, 0x0002, 0x01, 0xAAAAAAAA, byteorder="big")
        
        # 4 Send binary_op
        if interrupt:
            input("send binary op?")               # add - 0, sub - A, mul - 5, div - B
        self.send_instruction(0x7A, 0x01, 0x0000, 0x01, 0x0000000B, byteorder="big")
        
        # 5 Send store_name A
        if interrupt:
            input("send store name?")
        self.send_instruction(0x5A, 0x01, 0x0001, 0x01, 0x00000000, byteorder="big")
        
        # 6 Send push_null
        if interrupt:
            input("send push null?")
        self.send_instruction(0x02, 0x01, 0x0000, 0x01, 0x00000000, byteorder="big")
        
        # 7 Send load_name print
        if interrupt:
            input("send load name print?")
        self.send_instruction(0x65, 0x01, 0x0000, 0x05, 0x00000001, byteorder="big")
        
        # 8 Send load_name A
        if interrupt:
            input("send load name A?")
        self.send_instruction(0x65, 0x01, 0x0001, 0x04, 0x00000001, byteorder="big")
        
        # 9 Send call
        if interrupt:
            input("send call?")
        self.send_instruction(0xAB, 0x01, 0x0001, 0x01, 0x00000001, byteorder="big")
        
        # 10 Send pop_top
        if interrupt:
            input("send pop top?")
        self.send_instruction(0x01, 0x01, 0x0000, 0x01, 0x00000000, byteorder="big")
        

    def write_loop(self):
        """Continuously prompt for user input to send to the serial port"""
        
        first_send = True
        
        while not self.__stop_threads:
            command = input("Enter a command to send (or 'exit' to close): ")
            if command.lower() == 'exit':
                self.close_serial()  # Close the serial and stop the program
                break
            # self.send_message(command.encode())
            # # Send start
            
            if first_send:
                self.send_message(b'\x30')
                first_send = False
            
            # self.test_vm()
            self.execute_op(True)

    def close_serial(self) -> None:
        """Close serial connection and stop threads"""
        self.__stop_threads = True  # signal threads to stop
        if self.__serial:
            self.__serial.close()
        print("Serial closed")

# Usage
serial_connection = SerialConnection()
