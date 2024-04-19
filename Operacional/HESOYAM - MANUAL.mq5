//+------------------------------------------------------------------+
//|                                                              EGR |
//|                                             Enan Gobi Rosa, 2024 |
//+------------------------------------------------------------------+
#property copyright "Enan Gobi Rosa"
#property link      "HESOYAM Build: 01 - MANUAL"
#property version   "HESOYAM 2.0"

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh> // biblioteca CTrade

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+

//--- Lote
int vLoteInicial = 1;

//--- TP
double vTPInicial = 15;
double vTPAgregate = 13;

//--- SL
int vSL = 100;
double vSLDia = 1600;

//+------------------------------------------------------------------+
//| GLOBAIS                                                          |
//+------------------------------------------------------------------+
					   
//--- Variáveis

double vTPDia = 0;
double vPosicaoAtual = 0;

int vTicket = 0;
double vLote = 0;

bool vPosicaoAberta = false;

//--- Get Dados
CTrade trade;

MqlTick last_tick;

//+------------------------------------------------------------------+
//| Processamento ao Iniciar o EA                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   
//---
   return(INIT_SUCCEEDED);
}   
//+------------------------------------------------------------------+
//| Processamento ao Encerrar o EA                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   SalvarDadosBD();

}
//+------------------------------------------------------------------+
//| Processamento a cada Tick                                        |
//+------------------------------------------------------------------+
void OnTick()
{             
   //--- Se os dados foram lidos corretamente
   if (SymbolInfoTick(Symbol(), last_tick))
   {   	
   	//+------------------------------------------------------------------+
      //| Verifica se existe posição aberta e encerra com SL ou TP         |
      //+------------------------------------------------------------------+            
  
      if (PositionSelect(_Symbol))
      {         
         
         if (!vPosicaoAberta)
         {
            vPosicaoAberta = true;
            vPosicaoAtual = last_tick.last; 
            vLote = vLoteInicial;   
            vTPDia = vTPInicial;
         }
         
         if ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) && (last_tick.last <= (vPosicaoAtual - vSL)))
         {    
            vLote += vLoteInicial;    
            trade.Buy(vLote,_Symbol,0,0,0,"Compra");
            vPosicaoAtual = last_tick.last;
            vTPDia += (vTPAgregate * vLote); 
         }
        
         else if ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) && (last_tick.last >= (vPosicaoAtual + vSL)))
         {  
            vLote += vLoteInicial;     
            trade.Sell(vLote,_Symbol,0,0,0,"Venda");
            vPosicaoAtual = last_tick.last;
            vTPDia += (vTPAgregate * vLote);
         }
         
         //--- Encerra a posição        
         if ((PositionGetDouble(POSITION_PROFIT) >= vTPDia) || (PositionGetDouble(POSITION_PROFIT) <= (vSLDia * -1)))
         {
            vTicket = PositionGetInteger(POSITION_TICKET);            
            trade.PositionClose(vTicket);
            vPosicaoAberta = false;
         }   
      }   
   }
   //--- Se os dados NÃO foram lidos 
   else Print("Falha na leitura do Tick, erro: ",GetLastError());
}

//+------------------------------------------------------------------+
//|Biblioteca de Funções                                             |
//+------------------------------------------------------------------+

//---SalvarDadosBD-----------------------------------------------------------------------

void SalvarDadosBD()
{
   datetime vHora_Atual = TimeCurrent();   
   datetime vDia_Atual = ( vHora_Atual/86400 ) * 86400;
   
   HistorySelect(vDia_Atual , vHora_Atual);
   
   int vTotalOrdens = HistoryDealsTotal();
   
   int vTotalGainOP = 0;
   int vTotalLossOP = 0;
   
   double vResultadoOperacao = 0;
   double vTotalGainRS = 0;
   double vTotalLossRS = 0;
   
   int vDia; 
   int vMes;
   int vAno;
   
   string vCod_Ativo;
   
   double vTotalContratos;
   
   string query;         
      
   for(int i = 0; i < vTotalOrdens; i++)
   {
      ulong vTicket = HistoryDealGetTicket(i);
            
      if(vTicket > 1)
      {                
         string vCod_Ativo = HistoryDealGetString(vTicket,DEAL_SYMBOL);
         
         if ((vCod_Ativo != "") && (vCod_Ativo != NULL))
         {    
            vResultadoOperacao = HistoryDealGetDouble(vTicket, DEAL_PROFIT);  
   
            vTotalContratos += HistoryDealGetDouble(vTicket, DEAL_VOLUME);
           
            if (vResultadoOperacao > 0)
            {
               vTotalGainOP += 1;
               vTotalGainRS += vResultadoOperacao;
            }         
            else if (vResultadoOperacao < 0)
            {
               vTotalLossOP += 1;
               vTotalLossRS += (vResultadoOperacao * (-1));
                
            }
         }        
      }
   }
   
   MqlDateTime vData;      
   
   TimeToStruct(vHora_Atual,vData); 
   
   vDia = vData.day;  
   vMes = vData.mon;
   vAno = vData.year;  
   
   vCod_Ativo = HistoryDealGetString(vTicket,DEAL_SYMBOL);
   
   vTotalContratos /= 2;
      
   //--- Cria/Abre a base de dados
   int db = DatabaseOpen("DB_HESOYAM.db", DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | DATABASE_OPEN_COMMON);
      
   if (db==INVALID_HANDLE)
   {
      Print("Erro ao criar/abrir base de dados: ", GetLastError());
   }
   else
   {
      Print("Base de dados criada/aberta com sucesso.");
   };
        
   //--- Deleta os registros existentes
   query = "delete from EA_RESULTADOS " +
           "where DIA = " + IntegerToString(vDia) + " and " +
           "      MES = " + IntegerToString(vMes) + " and " +
           "      ANO = " + IntegerToString(vAno) + " and " +
           "      COD_ATIVO = '" + vCod_Ativo + "' and    " +
           "      USUARIO = 1 and CONTA = 'GENIAL';";

   if (!DatabaseExecute(db, query))
   {
      Print("Erro ao deletar os registros: ", GetLastError());
   }
   else
   {
      Print("Registros deletados com sucesso.");
   }

   //--- Insere os novos registros
   query = "insert into EA_RESULTADOS " +
           "   (DIA,                  " +
           "    MES,                  " +
           "    ANO,                  " +
           "    COD_ATIVO,            " +
           "    USUARIO,              " +
           "    CONTA,                " +
           "    TOTAL_GANHO_OP,       " +
           "    TOTAL_PERDA_OP,       " +
           "    TOTAL_CONTRATOS,      " + 
           "    TOTAL_GANHO_RS,       " + 
           "    TOTAL_PERDA_RS)       " +
           "VALUES (" + 
               IntegerToString(vDia)            + ", " + 
               IntegerToString(vMes)            + ", " +
               IntegerToString(vAno)            + ", '" +
               vCod_Ativo                       + "'," +
               "1"                              + ", " +
               "'GENIAL'"                       + ", " +
               IntegerToString(vTotalGainOP)    + ", " + 
               IntegerToString(vTotalLossOP)    + ", " + 
               IntegerToString(vTotalContratos) + ", " +
               DoubleToString(vTotalGainRS)     + ", " + 
               DoubleToString(vTotalLossRS)     + ")";
           
   if (!DatabaseExecute(db, query))
   {
      Print("Erro ao inserir os registros: ", GetLastError());
   }
   else
   {
      Print("Registros inseridos com sucesso.");
   }
   
   //--- Encerra a base de dados
   DatabaseClose(db);
   Print("Base de dados fechada com sucesso.");
   
}