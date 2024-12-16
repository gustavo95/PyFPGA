import dis
import marshal
import py_compile

from VirtualMachine import VirtualMachine

def load_pyc(file_path):
    with open(file_path, "rb") as f:
        f.read(16)  # Ignora o cabeçalho do arquivo `.pyc`
        code_obj = marshal.load(f)  # Carrega o objeto de código
    return code_obj

file_path = "./Teste/helloworld.py"
path_pyc = "./Teste/__pycache__/helloworld.cpython-313.pyc"

py_compile.compile(file_path)

code_obj = load_pyc(path_pyc)

print("Bytecode instructions: ")

instructions = dis.get_instructions(code_obj)
for instr in instructions:
    print(instr.opname, instr.arg, instr.argval)

print("---------------------------------")
print("\n")
print("Running code in Virtual Machine:")
    
vm = VirtualMachine()
vm.run_code(code_obj)