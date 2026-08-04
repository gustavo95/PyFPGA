import dis
import struct
from dataclasses import dataclass
from enum import IntEnum
from types import CodeType


# Os valores abaixo fazem parte do protocolo Python -> FPGA.
class OperandType(IntEnum):
    NONE = 0
    CODE_OBJECT = 1
    GLOBAL = 2
    BUILTIN = 3
    CONST = 4
    LOCAL = 5
    JUMP = 6
    IMMEDIATE = 7
    NAME = 8
    FREE_VAR = 9


class ConstType(IntEnum):
    NONE = 0
    BOOL = 1
    INT = 2
    FLOAT = 3
    STRING = 4
    BYTES = 5
    TUPLE = 6
    COMPLEX = 7
    ELLIPSIS = 8


# IDs internos da VM para builtins suportados.
BUILTIN_IDS = {
    "print": 0,
    "len": 1,
    "range": 2,
}


@dataclass(frozen=True)
class ConstOperand:
    """Constante transmitida como: type, len, data."""

    type: int
    len: int
    data: bytes


@dataclass
class LinearInstruction:
    pc: int
    opcode: int
    opname: str
    operand_type: int
    operand: object = None  # int para referência; ConstOperand para constante
    src_offset: int = 0
    comment: str = ""
    target_offset: int = None


def serializar_constante(value):
    """Converte uma constante Python para o triplo type/len/data."""

    if value is None:
        const_type, data = ConstType.NONE, b""
    elif isinstance(value, bool):
        const_type, data = ConstType.BOOL, bytes((int(value),))
    elif isinstance(value, int):
        const_type = ConstType.INT
        # Menor representação possível em complemento de dois.
        size = max(1, (value.bit_length() + 8) // 8)
        data = value.to_bytes(size, byteorder="big", signed=True)
    elif isinstance(value, float):
        const_type, data = ConstType.FLOAT, struct.pack(">d", value)
    elif isinstance(value, str):
        const_type, data = ConstType.STRING, value.encode("utf-8")
    elif isinstance(value, bytes):
        const_type, data = ConstType.BYTES, value
    elif isinstance(value, tuple):
        const_type = ConstType.TUPLE
        partes = []
        for item in value:
            const = serializar_constante(item)
            partes.append(bytes((const.type,)))
            partes.append(const.len.to_bytes(4, byteorder="big"))
            partes.append(const.data)
        data = b"".join(partes)
    elif isinstance(value, complex):
        const_type = ConstType.COMPLEX
        data = struct.pack(">dd", value.real, value.imag)
    elif value is Ellipsis:
        const_type, data = ConstType.ELLIPSIS, b""
    else:
        raise TypeError(
            f"constante {value!r} do tipo {type(value).__name__} não é suportada"
        )

    return ConstOperand(type=int(const_type), len=len(data), data=data)


class LinearizadorVM:
    def __init__(self):
        self.global_ids = {}
        self.code_ids = {}
        self.code_objects = []

    def get_global_id(self, name):
        if name not in self.global_ids:
            self.global_ids[name] = len(self.global_ids)
        return self.global_ids[name]

    def registrar_code_objects(self, code_obj):
        """Registra recursivamente o módulo e as funções nele definidas."""

        if id(code_obj) in self.code_ids:
            return self.code_ids[id(code_obj)]

        code_id = len(self.code_objects)
        self.code_ids[id(code_obj)] = code_id
        self.code_objects.append(code_obj)

        for const in code_obj.co_consts:
            if isinstance(const, CodeType):
                self.registrar_code_objects(const)

        return code_id

    def get_code_id(self, code_obj):
        return self.code_ids[id(code_obj)]

    def linearizar_todos(self, main_code_obj):
        self.registrar_code_objects(main_code_obj)

        resultado = {}
        for code_obj in self.code_objects:
            code_id = self.get_code_id(code_obj)
            instrucoes = self.linearizar_code_object(code_obj)
            resultado[code_id] = instrucoes

            print()
            print("=" * 100)
            print(f"CODE_OBJECT {code_id}: {code_obj.co_name}")
            print("=" * 100)
            self.printar_instrucoes(instrucoes)

        self.printar_tabelas()
        return resultado

    def linearizar_code_object(self, code_obj):
        # CACHE é detalhe interno do interpretador adaptativo e não é enviado à VM.
        instrucoes_python = list(dis.get_instructions(code_obj, show_caches=False))
        offset_to_pc = {
            instr.offset: pc for pc, instr in enumerate(instrucoes_python)
        }

        instrucoes = []
        for pc, instr in enumerate(instrucoes_python):
            operand_type, operand, comment, target_offset = self.classificar_operando(
                instr, code_obj
            )
            instrucoes.append(
                LinearInstruction(
                    pc=pc,
                    opcode=instr.opcode,
                    opname=instr.opname,
                    operand_type=int(operand_type),
                    operand=operand,
                    src_offset=instr.offset,
                    comment=comment,
                    target_offset=target_offset,
                )
            )

        for instr in instrucoes:
            if instr.target_offset is not None:
                instr.operand = self.resolver_target_pc(
                    instr.target_offset, offset_to_pc
                )

        return instrucoes

    @staticmethod
    def resolver_target_pc(target_offset, offset_to_pc):
        if target_offset in offset_to_pc:
            return offset_to_pc[target_offset]

        for offset in sorted(offset_to_pc):
            if offset >= target_offset:
                return offset_to_pc[offset]
        raise ValueError(f"não foi possível resolver target offset {target_offset}")

    def classificar_operando(self, instr, code_obj):
        op = instr.opname
        arg = instr.arg
        value = instr.argval

        if arg is None:
            return OperandType.NONE, None, "", None

        if op in ("LOAD_CONST", "RETURN_CONST"):
            if isinstance(value, CodeType):
                code_id = self.get_code_id(value)
                return OperandType.CODE_OBJECT, code_id, value.co_name, None
            const = serializar_constante(value)
            return OperandType.CONST, const, repr(value), None

        if op in ("LOAD_NAME", "LOAD_GLOBAL"):
            name = str(value)
            if name in BUILTIN_IDS:
                return OperandType.BUILTIN, BUILTIN_IDS[name], name, None
            return OperandType.GLOBAL, self.get_global_id(name), name, None

        if op in ("STORE_NAME", "STORE_GLOBAL", "DELETE_NAME", "DELETE_GLOBAL"):
            name = str(value)
            return OperandType.GLOBAL, self.get_global_id(name), name, None

        if instr.opcode in dis.haslocal:
            return OperandType.LOCAL, arg, str(value), None

        if instr.opcode in dis.hasfree:
            return OperandType.FREE_VAR, arg, str(value), None

        if instr.opcode in dis.hasjrel or instr.opcode in dis.hasjabs:
            return OperandType.JUMP, None, f"offset {value}", value

        if instr.opcode in dis.hasname:
            return OperandType.NAME, arg, str(value), None

        # Contagens, flags e seletores (CALL, MAKE_FUNCTION, BINARY_OP etc.).
        return OperandType.IMMEDIATE, arg, instr.argrepr, None

    def printar_tabelas(self):
        print("\n" + "=" * 100)
        print("GLOBALS")
        print("=" * 100)
        for name, gid in self.global_ids.items():
            print(f"{gid:04d}: {name}")

        print("\n" + "=" * 100)
        print("BUILTINS")
        print("=" * 100)
        for name, bid in BUILTIN_IDS.items():
            print(f"{bid:04d}: {name}")

    @staticmethod
    def printar_instrucoes(instrucoes):
        print(
            f"{'PC':>4}  {'OPCODE':<18} {'OPERAND_TYPE':<16} "
            f"{'OPERAND':<34} {'FROM'}"
        )
        print("-" * 100)

        for instr in instrucoes:
            type_name = OperandType(instr.operand_type).name
            if isinstance(instr.operand, ConstOperand):
                const = instr.operand
                const_name = ConstType(const.type).name
                operand = f"type={const_name}, len={const.len}, data={const.data.hex()}"
            else:
                operand = "" if instr.operand is None else str(instr.operand)

            print(
                f"{instr.pc:04d}  "
                f"{instr.opcode:02x} {instr.opname:<15} "
                f"{instr.operand_type:02x} {type_name:<13} "
                f"{operand:<34} "
                f"{instr.src_offset}: {instr.opname} {instr.comment}"
            )


def printar_linearizacao(code_obj):
    linearizador = LinearizadorVM()
    return linearizador.linearizar_todos(code_obj)
