"""Voz do Jarvis: carrega o modelo Piper UMA vez e fica esperando frases.

Entrada (stdin), uma por linha:  {"id": "...", "texto": "..."}
Saída (stdout), uma por linha:   {"id": "...", "wav": "/caminho.wav"}  ou  {"id": "...", "erro": "..."}

Sem porta de rede: só conversa com o servidor do Jarvis que o iniciou.
"""
import json
import os
import re
import sys
import tempfile
import wave

from piper import PiperVoice

voz = PiperVoice.load(sys.argv[1])
pasta = tempfile.mkdtemp(prefix="jarvis-voz-")

for linha in sys.stdin:
    pedido = {}
    try:
        pedido = json.loads(linha)
        ident = re.sub(r"[^a-zA-Z0-9-]", "", str(pedido["id"]))[:64]
        caminho = os.path.join(pasta, ident + ".wav")
        with wave.open(caminho, "wb") as arquivo:
            voz.synthesize_wav(str(pedido["texto"]), arquivo)
        print(json.dumps({"id": pedido["id"], "wav": caminho}), flush=True)
    except Exception as erro:  # uma frase ruim não derruba a voz
        print(json.dumps({"id": pedido.get("id"), "erro": str(erro)}), flush=True)
