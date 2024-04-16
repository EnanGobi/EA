import sqlite3
import locale
import telegram
import asyncio
import math

from datetime import date

class Totais:
    diario_valor = 0.0
    diario_contratos = 0
    diario_percentual = 0.0
    valor_aplicado = 2600

    taxas_emonumentos = 0
    taxas_irrf = 0
    taxas_registro = 0
    taxas_total = 0

    def carregar_diario(self):
        dia = date.today().strftime("%d")
        mes = date.today().strftime("%m")
        ano = date.today().strftime("%G")

        sql_diario = f"select r.TOTAL_GANHO_RS - R.TOTAL_PERDA_RS AS TOTAL, r.TOTAL_CONTRATOS from ea_resultados r where dia = '{int(dia)}' and mes = '{int(mes)}' and ano = '{ano}' and conta = 'CLEAR'"

        rs = execute_sql(sql_diario)
        
        if rs.arraysize > 0:
            row = rs.fetchone()
            self.diario_valor = row[0]
            self.diario_contratos = row[1]
            self.diario_percentual = ((self.diario_valor * 100) / self.valor_aplicado) /100
        
        rs.close
        rs.connection.close
    
    def carregar_taxas(self):
        tx_registro = 0.32
        tx_emonumentos = 0.18

        self.taxas_registro = tx_registro * self.diario_contratos
        self.taxas_emonumentos = tx_emonumentos * self.diario_contratos

        valor = self.diario_valor - self.taxas_emonumentos - self.taxas_registro
       
        resto = ((valor * 0.01)*1000000) % 10

        if resto <= 5:
            self.taxas_irrf = truncate((valor * 0.01),2)
        else:
            self.taxas_irrf = round((valor * 0.01),2)

        self.taxas_total = self.taxas_emonumentos + self.taxas_irrf + self.taxas_irrf

    def total_diario(self):
        return self.diario_valor - self.taxas_total

    def total_diario_investidor(self):
        return self.total_diario() * 0.35

def truncate(number, decimals=0):
    """
    Returns a value truncated to a specific number of decimal places.
    """
    if not isinstance(decimals, int):
        raise TypeError("decimal places must be an integer.")
    elif decimals < 0:
        raise ValueError("decimal places has to be 0 or more.")
    elif decimals == 0:
        return math.trunc(number)

    factor = 10.0 ** decimals
    return math.trunc(number * factor) / factor

def execute_sql(comando: str):
    con = sqlite3.connect("C:\\Users\\Administrator\\AppData\\Roaming\\MetaQuotes\\Terminal\\Common\\Files\\DB_HESOYAM.db")
    cur = con.cursor()
    res = cur.execute(comando)
    return res

def get_mensagem():
    totais = Totais()
    totais.carregar_diario()
    totais.carregar_taxas()
    
    data = date.today().strftime("%d/%m/%G")

    mensagem = f"Resultados do dia {data}\n"
    mensagem = mensagem + f"Saldo do Dia: {locale.currency(totais.diario_valor)}\n"
    mensagem = mensagem + f"Contratos Negociados: {totais.diario_contratos}\n"
    mensagem = mensagem + f"Lucro Sobre o Valor Aplicado: " + "{:.2%}".format(totais.diario_percentual)
    mensagem = mensagem + "\n\n"
    mensagem = mensagem + "Taxas\n"
    mensagem = mensagem + f"IRRF: {locale.currency(totais.taxas_irrf)}\n"
    mensagem = mensagem + f"Registro: {locale.currency(totais.taxas_registro)}\n"
    mensagem = mensagem + f"Emolumentos: {locale.currency(totais.taxas_emonumentos)}"
    mensagem = mensagem + "\n\n"
    mensagem = mensagem + f"Total Líquido: {locale.currency(totais.total_diario())}\n"
    mensagem = mensagem + f"Parte do Investidor: {locale.currency(totais.total_diario() * 0.35)}\n"
    mensagem = mensagem + f"Parte do Bot: {locale.currency(totais.total_diario() * 0.30)}"
    mensagem = mensagem + "\n\n"


    return mensagem


if __name__ == '__main__':
    locale.setlocale(locale.LC_MONETARY,'pt_BR.UTF-8')

    meu_token = '7148549027:AAE1XH3j3oLUO9YxN5BIY4VKzoHhJflqFC4'
    id_grupo = -1002091617188
    
    bot = telegram.Bot(token=meu_token)
    asyncio.run(bot.send_message(chat_id = id_grupo, text = get_mensagem()))