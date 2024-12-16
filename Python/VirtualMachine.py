import dis

class VirtualMachine:
    def __init__(self):
        self.stack = []
        self.type_stack = []
        self.names = {}
        
    def push(self, value, is_function = False):
        self.stack.append(value)
        self.type_stack.append(1 if is_function else 0)

    def pop(self):
        value = self.stack.pop()
        value_type = self.type_stack.pop()
        return value, value_type

    def run_code(self, code_obj):
        instructions = dis.get_instructions(code_obj)
        for instr in instructions:
            self.dispatch(instr.opname, instr.arg, instr.argval)
            print(instr.opname, instr.arg, instr.argval, self.stack)

    def dispatch(self, opname, arg, argval):
        if opname == 'RESUME':
            pass
        elif opname == 'LOAD_CONST':
            #Coloca o valor na pilha
            self.push(argval)
        elif opname == 'LOAD_FAST':
            self.push(argval)
        elif opname == 'BINARY_OP':
            #Realiza a operação binária
            b, _ = self.pop()
            a, _ = self.pop()
            if argval == 0:
                self.push(a + b)
            elif argval == 10:
                self.push(a - b)
            elif argval == 5:
                self.push(a * b)
            elif argval == 11:
                self.push(a / b)
            elif argval == 2:
                self.push(a // b)
            elif argval == 6:
                self.push(a % b)
            elif argval == 4:
                self.push(a @ b)
            elif argval == 8:
                self.push(a ** b)
            else:
                print(f"Operação binaria não implementada: {opname} {argval}")
                raise NotImplementedError
        elif opname == 'RETURN_VALUE':
            #Imprime o valor do topo da pilha como retorno
            print(f"Return: {self.pop()}")
        elif opname == 'RETURN_CONST':
            #Imprime o valor do argumento como retorno
            print(f"Return: {argval}")
        elif opname == 'STORE_NAME':
            #Tira da pilha o valor e coloca no dicionário de nomes
            value, _ = self.pop()
            self.names[argval] = value
        elif opname == 'LOAD_NAME':
            #Pega o valor do dicionário de nomes e coloca na pilha
            if argval == "print":
                self.push(1, True)  # Empilha referência à função print
            else:
                value = self.names.get(argval, None)
                self.push(value)
        elif opname == 'PUSH_NULL' :
            #Coloca um valor nulo na pilha
            self.push(None)
        elif opname == 'PRECALL':
            pass
        elif opname == 'CALL':
            arg, _ = self.pop()
            func, type = self.pop()
            if type == 1:
                if func == 1:
                    print("Print:", arg)
        elif opname == 'POP_TOP':
            self.pop()
        else :
            print(f"Operação não implementada: {opname}")
            raise NotImplementedError