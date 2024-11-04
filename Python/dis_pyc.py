import dis
import marshal
import py_compile
import time
from types import CodeType
import dis
import struct

def ler_binario_em_hex(arquivo):
    try:
        with open(arquivo, 'rb') as f:
            # Lê todo o conteúdo do arquivo
            conteudo = f.read()
            
            # Imprime o conteúdo em hexadecimal
            print("Conteúdo em hexadecimal:")
            i = 0
            for byte in conteudo:
                print(f"{byte:02x}", end=' ')
                i += 1
                if i % 16 == 0:
                    print()  # Para pular para a próxima linha após a impressão
            print()  # Para pular para a próxima linha após a impressão
            
    except FileNotFoundError:
        print(f"Erro: O arquivo '{arquivo}' não foi encontrado.")
    except Exception as e:
        print(f"Ocorreu um erro: {e}")

# Função para mapear opcodes para seus nomes
def decode_opcodes(opcodes):
    for opcode in opcodes:
        if opcode != 0:
            instruction = dis.opname[opcode]
            print(f"{opcode}: {instruction}")

def ler_pyc(arquivo_pyc):
    with open(arquivo_pyc, "rb") as f:
        # Ler e exibir o header de 16 bytes
        versao_magica = f.read(4)
        bit_field = f.read(4)
        timestamp = int.from_bytes(f.read(4), 'little')
        tamanho_arquivo = int.from_bytes(f.read(4), 'little')
        
        print("Versão Mágica:", versao_magica)
        print("Campo de Bits:", bit_field)
        print("Timestamp:", timestamp, f"({time.ctime(timestamp)})" if timestamp != 0 else "(timestamp ausente)")
        print("Tamanho do Arquivo:", tamanho_arquivo)
        
        # Carregar o bytecode usando marshal
        code_object = marshal.load(f)
        return code_object

def exibir_bytecode(code_object):
    # Usar `dis` para descompilar o bytecode
    
    print("co_argcount:", hex(code_object.co_argcount))
    print("co_kwonlyargcount:", hex(code_object.co_kwonlyargcount))
    print("co_nlocals:", hex(code_object.co_nlocals))
    print("co_stacksize:", hex(code_object.co_stacksize))
    print("co_flags:", hex(code_object.co_flags))
    print("co_code:", list(code_object.co_code))
    print("co_consts:", list(code_object.co_consts))
    print("co_names:", list(code_object.co_names))
    print("co_varnames:", list(code_object.co_varnames))
    print("co_filename:", code_object.co_filename)
    print("co_name:", code_object.co_name)
    print("co_firstlineno:", hex(code_object.co_firstlineno))
    print("co_lnotab:", code_object.co_lnotab)
    print("co_freevars:", list(code_object.co_freevars))
    print("co_cellvars:", list(code_object.co_cellvars))
    print()
    
    # print("Nome do Código:", code_object.co_name)
    # print("Número de Argumentos:", code_object.co_argcount)
    # print("Nomes das Variáveis Locais:", code_object.co_varnames)
    # print("Código Bytecode:", list(code_object.co_code))
    # print("Arquivo de Origem:", code_object.co_filename)
    # decode_opcodes(list(code_object.co_code))
    # dis.dis(code_object)
    
def ler_int(f):
    bytes_lidos = f.read(4)
    if len(bytes_lidos) < 4:
        return None
    return struct.unpack('<I', bytes_lidos)[0]

def decodificar_pyc(arquivo):
    with open(arquivo, 'rb') as f:
        # Ignorar os primeiros 16 bytes do header
        f.seek(17)

        # Coletar informações do Code Object
        co_argcount = ler_int(f)                  # Número de argumentos
        co_kwonlyargcount = ler_int(f)            # Número de argumentos keyword-only
        co_nlocals = ler_int(f)                   # Número de variáveis locais
        co_stacksize = ler_int(f)                 # Tamanho da pilha
        co_flags = ler_int(f)                     # Flags

        print("Extracted Code Object Information")
        # Exibir informações do Code Object
        print(f"co_argcount: {co_argcount}")
        print(f"co_kwonlyargcount: {co_kwonlyargcount}")
        print(f"co_nlocals: {co_nlocals}")
        print(f"co_stacksize: {co_stacksize}")
        print(f"co_flags: {co_flags}")

        # Ler o co_code (bytecode)
        co_code_size = ler_int(f)  # Tamanho do bytecode
        print(f"co_code_size: {co_code_size}")
        co_code = f.read(co_code_size)  # Lê o bytecode
        print(f"co_code (hex): {' '.join(f'{byte:02x}' for byte in co_code)}")

        # Ler co_consts
        num_consts = ler_int(f)  # Número de constantes
        co_consts = []
        for _ in range(num_consts):
            const_index = ler_int(f)  # Índice da constante
            co_consts.append(const_index)

        print(f"co_consts (indices): {co_consts}")

        # Ler co_names
        num_names = ler_int(f)  # Número de nomes
        co_names = []
        for _ in range(num_names):
            name_index = ler_int(f)  # Índice do nome
            co_names.append(name_index)

        print(f"co_names (indices): {co_names}")

        # Ler co_varnames
        num_varnames = ler_int(f)  # Número de variáveis locais
        co_varnames = []
        for _ in range(num_varnames):
            varname_index = ler_int(f)  # Índice da variável
            co_varnames.append(varname_index)

        print(f"co_varnames (indices): {co_varnames}")

        # Ler co_filename
        filename_index = ler_int(f)
        print(f"co_filename index: {filename_index}")

        # Ler co_name
        name_index = ler_int(f)
        print(f"co_name index: {name_index}")

        # Ler co_firstlineno
        co_firstlineno = ler_int(f)
        print(f"co_firstlineno: {co_firstlineno}")

        # Ler co_lnotab (tabela de números de linha)
        co_lnotab_size = ler_int(f)  # Tamanho da tabela de números de linha
        co_lnotab = f.read(co_lnotab_size)
        print(f"co_lnotab (hex): {' '.join(f'{byte:02x}' for byte in co_lnotab)}")

        # Ler co_freevars
        num_freevars = ler_int(f)  # Número de variáveis livres
        co_freevars = []
        for _ in range(num_freevars):
            freevar_index = ler_int(f)  # Índice da variável livre
            co_freevars.append(freevar_index)

        print(f"co_freevars (indices): {co_freevars}")

        # Ler co_cellvars
        num_cellvars = ler_int(f)  # Número de variáveis de célula
        co_cellvars = []
        for _ in range(num_cellvars):
            cellvar_index = ler_int(f)  # Índice da variável de célula
            co_cellvars.append(cellvar_index)

        print(f"co_cellvars (indices): {co_cellvars}")


py_compile.compile("./Teste/helloworld.py")

ler_binario_em_hex("./Teste/__pycache__/helloworld.cpython-311.pyc")

# Caminho para o arquivo .pyc
caminho_arquivo_pyc = "./Teste/__pycache__/helloworld.cpython-311.pyc"

# Ler e decodificar o arquivo .pyc
code_obj = ler_pyc(caminho_arquivo_pyc)

# Exibir o bytecode
print("\nBytecode:")
exibir_bytecode(code_obj)

decodificar_pyc("./Teste/__pycache__/helloworld.cpython-311.pyc")