"""Compila Python e gera uma saída legível e outra binária para a FPGA.

O arquivo binário é big-endian e composto somente por palavras de 32 bits.
Cada instrução ocupa duas palavras:
    palavra 0 = opcode[31:24] tipo[23:20] subtipo[19:16] auxiliar[15:0]
    palavra 1 = operando, dado imediato ou endereço no pool de constantes
"""

from pathlib import Path
import struct
import sys
import tokenize

from py_bytecode_linear import (
    BUILTIN_IDS,
    ConstOperand,
    ConstType,
    LinearizadorVM,
    OperandType,
)


# Altere esta string para apontar para um arquivo .py ou para uma pasta.
CAMINHO_ENTRADA = r"Teste\helloworld.py"

# Se for relativo, o caminho é resolvido a partir da pasta deste script.
CAMINHO_SAIDA = r"bytecode_linear.txt"
CAMINHO_SAIDA_BINARIA = r"bytecode_linear.bin"


VERSAO_FORMATO_BINARIO = 1

MAGIC_BINARIO = 0x50594650  # ASCII "PYFP"
PALAVRAS_CABECALHO = 13
PALAVRAS_POR_CODE_OBJECT = 5
PALAVRAS_POR_INSTRUCAO = 2
FLAG_CONSTANTE_NO_POOL = 0x8000
MASCARA_TAMANHO_CONSTANTE = 0x7FFF


def resolver_caminho(caminho):
    caminho = Path(caminho)
    if not caminho.is_absolute():
        caminho = Path(__file__).resolve().parent / caminho
    return caminho.resolve()


def encontrar_fontes(caminho_entrada):
    if caminho_entrada.is_file():
        if caminho_entrada.suffix.lower() != ".py":
            raise ValueError(f"o arquivo de entrada deve terminar em .py: {caminho_entrada}")
        return [caminho_entrada]

    if caminho_entrada.is_dir():
        fontes = sorted(
            caminho
            for caminho in caminho_entrada.rglob("*.py")
            if "__pycache__" not in caminho.parts
        )
        if not fontes:
            raise ValueError(f"nenhum arquivo .py encontrado em: {caminho_entrada}")
        return fontes

    raise FileNotFoundError(f"entrada não encontrada: {caminho_entrada}")


def compilar_fonte(caminho):
    # tokenize.open respeita comentários como '# -*- coding: latin-1 -*-'.
    with tokenize.open(caminho) as arquivo:
        fonte = arquivo.read()
    return compile(fonte, str(caminho), "exec", dont_inherit=True)


def adicionar_constante_ao_pool(data, pool, enderecos):
    if data in enderecos:
        return enderecos[data]

    endereco = len(pool)
    enderecos[data] = endereco
    for inicio in range(0, len(data), 4):
        bloco = data[inicio : inicio + 4].ljust(4, b"\0")
        pool.append(int.from_bytes(bloco, byteorder="big"))
    return endereco


def empacotar_instrucao(instrucao, pool, enderecos):
    tipo = int(instrucao.operand_type)
    subtipo = 0
    auxiliar = 0
    operando = 0

    if isinstance(instrucao.operand, ConstOperand):
        constante = instrucao.operand
        subtipo = constante.type
        tamanho = constante.len
        if tamanho > MASCARA_TAMANHO_CONSTANTE:
            raise ValueError(
                f"constante no PC {instrucao.pc} excede 32767 bytes: {tamanho}"
            )

        # Escalares de até 32 bits são executados sem acesso ao pool.
        if subtipo in (ConstType.NONE, ConstType.BOOL):
            auxiliar = tamanho
            operando = int.from_bytes(constante.data or b"\0", byteorder="big")
        elif subtipo == ConstType.INT and tamanho <= 4:
            auxiliar = tamanho
            valor = int.from_bytes(constante.data, byteorder="big", signed=True)
            operando = valor & 0xFFFFFFFF
        else:
            auxiliar = FLAG_CONSTANTE_NO_POOL | tamanho
            operando = adicionar_constante_ao_pool(
                constante.data, pool, enderecos
            )
    elif instrucao.operand is not None:
        operando = int(instrucao.operand) & 0xFFFFFFFF

    if not 0 <= instrucao.opcode <= 0xFF:
        raise ValueError(f"opcode fora de 8 bits: {instrucao.opcode}")
    if not 0 <= tipo <= 0xF or not 0 <= subtipo <= 0xF:
        raise ValueError("tipo ou subtipo não cabe em 4 bits")

    controle = (
        (instrucao.opcode << 24)
        | (tipo << 20)
        | (subtipo << 16)
        | auxiliar
    )
    return controle, operando


def gerar_palavras_binarias(raizes, blocos, linearizador):
    pool = []
    enderecos_constantes = {}
    palavras_instrucoes = []
    inicio_instrucoes = {}
    quantidade_total = 0

    for code_id, _, instrucoes in blocos:
        inicio_instrucoes[code_id] = quantidade_total
        for instrucao in instrucoes:
            palavras_instrucoes.extend(
                empacotar_instrucao(instrucao, pool, enderecos_constantes)
            )
            quantidade_total += 1

    offset_arquivos = PALAVRAS_CABECALHO
    offset_codes = offset_arquivos + len(raizes)
    offset_instrucoes = (
        offset_codes + len(blocos) * PALAVRAS_POR_CODE_OBJECT
    )
    offset_constantes = offset_instrucoes + len(palavras_instrucoes)

    cabecalho = [
        MAGIC_BINARIO,
        VERSAO_FORMATO_BINARIO,
        PALAVRAS_CABECALHO,
        len(raizes),
        len(blocos),
        len(linearizador.global_ids),
        len(BUILTIN_IDS),
        quantidade_total,
        offset_arquivos,
        offset_codes,
        offset_instrucoes,
        offset_constantes,
        len(pool),
    ]

    tabela_arquivos = [code_id for _, code_id in raizes]
    tabela_codes = []
    for code_id, code_object, instrucoes in blocos:
        tabela_codes.extend(
            [
                inicio_instrucoes[code_id],
                len(instrucoes),
                code_object.co_argcount,
                code_object.co_nlocals,
                code_object.co_stacksize,
            ]
        )

    return cabecalho + tabela_arquivos + tabela_codes + palavras_instrucoes + pool


def escrever_binario(caminho, palavras):
    caminho.parent.mkdir(parents=True, exist_ok=True)
    with caminho.open("wb") as arquivo:
        for palavra in palavras:
            if not 0 <= palavra <= 0xFFFFFFFF:
                raise ValueError(f"palavra fora de 32 bits: {palavra}")
            arquivo.write(struct.pack(">I", palavra))


def linha_palavra(indice, valor, significado):
    return f"word[{indice:04X}] = 0x{valor:08X}  {significado}"


def gerar_texto_legivel(palavras, raizes, blocos, linearizador):
    nomes_cabecalho = [
        "magic = 'PYFP'",
        "versão do formato binário",
        "tamanho do cabeçalho em palavras",
        "quantidade de arquivos",
        "quantidade de code objects",
        "quantidade de globais",
        "quantidade de builtins",
        "quantidade total de instruções",
        "endereço da tabela de arquivos",
        "endereço da tabela de code objects",
        "endereço da memória de instruções",
        "endereço do pool de constantes",
        "tamanho do pool em palavras",
    ]
    linhas = [
        "BYTECODE LINEAR PARA FPGA",
        "Todos os valores abaixo correspondem exatamente ao arquivo .bin.",
        "Cada word possui 32 bits e o arquivo usa byte order big-endian.",
        "Os índices word[....] são endereços de palavras escritos em hexadecimal.",
        "",
        "=== CABEÇALHO ===",
    ]
    for indice, significado in enumerate(nomes_cabecalho):
        linhas.append(linha_palavra(indice, palavras[indice], significado))

    indice = palavras[8]
    linhas.extend(["", "=== TABELA DE ARQUIVOS ==="])
    for arquivo_id, (fonte, code_id) in enumerate(raizes):
        linhas.append(
            linha_palavra(
                indice,
                palavras[indice],
                f"arquivo {arquivo_id}: code_object raiz = {code_id} ({fonte})",
            )
        )
        indice += 1

    linhas.extend(["", "=== TABELA DE CODE OBJECTS ==="])
    campos_code = [
        "primeira instrução",
        "quantidade de instruções",
        "quantidade de argumentos",
        "quantidade de variáveis locais",
        "tamanho máximo da pilha",
    ]
    indice = palavras[9]
    for code_id, code_object, _ in blocos:
        linhas.append(f"\nCODE_OBJECT {code_id}: {code_object.co_name}")
        for campo in campos_code:
            linhas.append(
                linha_palavra(
                    indice,
                    palavras[indice],
                    f"code_object {code_id}: {campo}",
                )
            )
            indice += 1

    linhas.extend(
        [
            "",
            "=== MEMÓRIA DE INSTRUÇÕES ===",
            "CONTROL = opcode[31:24] | operand_type[23:20] | "
            "const_type[19:16] | auxiliar[15:0]",
        ]
    )
    indice = palavras[10]
    for code_id, code_object, instrucoes in blocos:
        linhas.append(f"\nCODE_OBJECT {code_id}: {code_object.co_name}")
        for instrucao in instrucoes:
            controle = palavras[indice]
            operando = palavras[indice + 1]
            tipo = OperandType(instrucao.operand_type)
            subtipo = (controle >> 16) & 0xF
            auxiliar = controle & 0xFFFF

            linhas.append(
                f"\nPC {instrucao.pc:04X}: opcode 0x{instrucao.opcode:02X} "
                f"({instrucao.opname})"
            )
            linhas.append(linha_palavra(indice, controle, "CONTROL"))
            linhas.append(
                f"    opcode      = 0x{instrucao.opcode:02X} "
                f"({instrucao.opname})"
            )
            linhas.append(
                f"    operand_type= 0x{tipo.value:X} ({tipo.name})"
            )

            if isinstance(instrucao.operand, ConstOperand):
                const_type = ConstType(subtipo)
                no_pool = bool(auxiliar & FLAG_CONSTANTE_NO_POOL)
                tamanho = auxiliar & MASCARA_TAMANHO_CONSTANTE
                linhas.append(
                    f"    const_type  = 0x{subtipo:X} ({const_type.name})"
                )
                linhas.append(
                    f"    pool_flag   = 0x{int(no_pool):X} "
                    f"({'POOL' if no_pool else 'INLINE'})"
                )
                linhas.append(
                    f"    length      = 0x{tamanho:04X} ({tamanho} bytes)"
                )
                significado = (
                    f"endereço relativo ao início do pool = 0x{operando:08X}"
                    if no_pool
                    else f"constante inline = {instrucao.comment}"
                )
            else:
                linhas.append("    const_type  = 0x0 (não se aplica)")
                linhas.append(f"    auxiliar    = 0x{auxiliar:04X}")
                significado = (
                    "sem operando"
                    if tipo == OperandType.NONE
                    else f"{tipo.name.lower()} = {instrucao.operand}"
                )
                if instrucao.comment:
                    significado += f" ({instrucao.comment})"

            linhas.append(linha_palavra(indice + 1, operando, significado))
            indice += PALAVRAS_POR_INSTRUCAO

    linhas.extend(["", "=== POOL DE CONSTANTES ==="])
    inicio_pool = palavras[11]
    fim_pool = inicio_pool + palavras[12]
    if inicio_pool == fim_pool:
        linhas.append("(vazio)")
    else:
        for indice in range(inicio_pool, fim_pool):
            valor = palavras[indice]
            bytes_hex = " ".join(f"{byte:02X}" for byte in valor.to_bytes(4, "big"))
            linhas.append(
                linha_palavra(indice, valor, f"bytes = {bytes_hex}")
            )

    linhas.extend(["", "=== TABELAS DE REFERÊNCIA ===", "GLOBALS"])
    if linearizador.global_ids:
        for nome, global_id in linearizador.global_ids.items():
            linhas.append(f"0x{global_id:08X} = {nome}")
    else:
        linhas.append("(vazia)")

    linhas.append("\nBUILTINS")
    for nome, builtin_id in BUILTIN_IDS.items():
        linhas.append(f"0x{builtin_id:08X} = {nome}")

    return "\n".join(linhas) + "\n"


def gerar_bytecode_linear(caminho_entrada, caminho_saida, caminho_saida_binaria=None):
    entrada = resolver_caminho(caminho_entrada)
    saida = resolver_caminho(caminho_saida)
    if caminho_saida_binaria is None:
        saida_binaria = saida.with_suffix(".bin")
    else:
        saida_binaria = resolver_caminho(caminho_saida_binaria)
    fontes = encontrar_fontes(entrada)

    linearizador = LinearizadorVM()
    raizes = []

    # Todos são registrados antes da linearização para que os IDs sejam estáveis.
    for fonte in fontes:
        code_raiz = compilar_fonte(fonte)
        code_id = linearizador.registrar_code_objects(code_raiz)
        raizes.append((fonte, code_id))

    blocos = []
    for code_object in linearizador.code_objects:
        code_id = linearizador.get_code_id(code_object)
        instrucoes = linearizador.linearizar_code_object(code_object)
        blocos.append((code_id, code_object, instrucoes))

    palavras = gerar_palavras_binarias(raizes, blocos, linearizador)
    escrever_binario(saida_binaria, palavras)
    texto = gerar_texto_legivel(palavras, raizes, blocos, linearizador)
    saida.parent.mkdir(parents=True, exist_ok=True)
    # O BOM faz o Windows PowerShell e editores antigos reconhecerem o UTF-8.
    saida.write_text(texto, encoding="utf-8-sig")
    total_instrucoes = sum(len(i) for _, _, i in blocos)
    return (
        saida,
        saida_binaria,
        len(fontes),
        len(blocos),
        total_instrucoes,
        len(palavras),
    )


def main():
    entrada = sys.argv[1] if len(sys.argv) > 1 else CAMINHO_ENTRADA
    saida = sys.argv[2] if len(sys.argv) > 2 else CAMINHO_SAIDA
    if len(sys.argv) > 3:
        saida_binaria = sys.argv[3]
    elif len(sys.argv) > 2:
        # Ao informar apenas a saída legível, usa o mesmo nome com extensão .bin.
        saida_binaria = None
    else:
        saida_binaria = CAMINHO_SAIDA_BINARIA
    arquivo, binario, fontes, code_objects, instrucoes, palavras = (
        gerar_bytecode_linear(entrada, saida, saida_binaria)
    )
    print(f"Arquivo legível gerado: {arquivo}")
    print(f"Arquivo binário gerado: {binario}")
    print(f"{fontes} fonte(s), {code_objects} code object(s), {instrucoes} instrução(ões)")
    print(f"{palavras} palavra(s) de 32 bits, {palavras * 4} bytes")


if __name__ == "__main__":
    main()
