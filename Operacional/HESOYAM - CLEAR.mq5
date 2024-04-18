//+------------------------------------------------------------------+
//|                                                              EGR |
//|                                             Enan Gobi Rosa, 2024 |
//+------------------------------------------------------------------+
#property copyright "Enan Gobi Rosa"
#property link      "HESOYAM Build: 01 - CLEAR"
#property version   "HESOYAM 2.0"

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh> // biblioteca CTrade

#import "shell32.dll"
int ShellExecuteW(int hwnd,string Operation,string File,string Parameters,string Directory,int ShowCmd);
#import

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+

//--- Lote
int vLoteInicial = 1;

//--- TP
double vTPInicial = 15;
double vTPAgregate = 13;

double vLimiteTPRS = 55;
int vLimiteTPOP = 3;

//--- SL
int vSL = 100;

double vSLDia = 1580;

double vLimiteSLRS = 200;
int vLimiteSLOP = 3;

//+------------------------------------------------------------------+
//| GLOBAIS                                                          |
//+------------------------------------------------------------------+
					   
//--- Variáveis
double vTPDia = 0;
double vPosicaoAtual = 0;

int vTicket = 0;
double vLote = 0;

bool vExpediente = false;
bool vFechamento = false;
bool vPosicaoAberta = false;

int vSinalCompra = 0;
int vSinalVenda = 0;

//--- Get Dados
CTrade trade;

MqlRates dadosdopreco[];
MqlTick last_tick;

//+------------------------------------------------------------------+
//| Processamento ao Iniciar o EA                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   ArraySetAsSeries(dadosdopreco,true);
   
//---
   return(INIT_SUCCEEDED);
}   
//+------------------------------------------------------------------+
//| Processamento ao Encerrar o EA                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   SalvarDadosBD();
   
   //Envia Mensagem no grupo do telegram com o resumo do dia
   ShellExecuteW(NULL, "open", "C:\Hesoyam\simple_bot_clear.py", "", "", 0);

}
//+------------------------------------------------------------------+
//| Processamento a cada Tick                                        |
//+------------------------------------------------------------------+
void OnTick()
{          
   vExpediente = Expediente(09,00,09,40,TimeCurrent());
   vFechamento = Expediente(17,50,18,00,TimeCurrent());
   
   //--- Se os dados foram lidos corretamente
   if (SymbolInfoTick(Symbol(), last_tick))
   {   	
   	//+------------------------------------------------------------------+
      //| Verifica se existe posição aberta e encerra com SL ou TP         |
      //+------------------------------------------------------------------+ 
           
      if (vPosicaoAberta)
      {
         if (PositionSelect(_Symbol))
         {                  
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
            if (((PositionGetDouble(POSITION_PROFIT) >= vTPDia) || (PositionGetDouble(POSITION_PROFIT) <= (vSLDia * -1))) || (vFechamento))
            {
               vLote = PositionGetDouble(POSITION_VOLUME);
               vPosicaoAberta = false;
               
               if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               {
                  trade.Sell(vLote,_Symbol,0,0,0,"Fechamento Venda");
               }
               
               else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               {
                  trade.Buy(vLote,_Symbol,0,0,0,"Fechamento Compra");
               }            
            }
         }
      //--- Encerra o terminal
      }else if ((Limites(vLimiteTPOP, vLimiteTPRS, vLimiteSLOP, vLimiteSLRS)) || (vFechamento))
      {
         //TerminalClose(100);        
	        
      //+------------------------------------------------------------------+
      //| Validações para a execução das ordens                            |
      //+------------------------------------------------------------------+
   	
   	//--- Recebe os dados dos indicadores
      }else
   	{
         int basededadosdopreco = CopyRates(_Symbol,_Period,0,Bars(_Symbol,_Period),dadosdopreco);         
               
         if (vExpediente)
         {
            //--- Valida o spread
            if (((last_tick.bid - last_tick.ask) <= 20 && (last_tick.bid - last_tick.ask) >= 0) || 
                ((last_tick.ask - last_tick.bid) <= 20 && (last_tick.ask - last_tick.bid) >= 0))
            {   
               //--- Ordem de Compra
               if ((last_tick.last > 0) && (last_tick.last > dadosdopreco[1].close))
               {  
                  vSinalVenda = 0;
                  vSinalCompra += 1;
                  
                  if (vSinalCompra == 100)
                  {               
                     trade.Buy(vLoteInicial,_Symbol,0,0,0,"Compra");
                     vPosicaoAtual = last_tick.last; 
                     vLote = vLoteInicial;   
                     vTPDia = vTPInicial;
                     vSinalCompra = 0;
                     vPosicaoAberta = true;
                  }
               }
               //--- Ordem de Venda
               else if ((last_tick.last > 0) && (last_tick.last < dadosdopreco[1].close))
               {  
                  vSinalCompra = 0;
                  vSinalVenda += 1;
                  
                  if (vSinalVenda == 100)
                  {               
                     trade.Sell(vLoteInicial,_Symbol,0,0,0,"Venda");
                     vPosicaoAtual = last_tick.last;  
                     vLote = vLoteInicial;    
                     vTPDia = vTPInicial;
                     vSinalVenda = 0; 
                     vPosicaoAberta = true;
                  }  
               }                          
            }
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
           "      USUARIO = 1 and CONTA = 'CLEAR';";

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
               "'CLEAR'"                        + ", " +
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

//---Expediente--------------------------------------------------------------------------

bool Expediente(int HoraInicial, int MinutoInicial, int HoraFinal, int MinutoFinal, datetime HoraCorrente)
{
   //--- Hora Inicial
   int StartTime=3600*HoraInicial+60*MinutoInicial;
   int StopTime=3600*HoraFinal+60*MinutoFinal;
   
   //--- current time in seconds since the day start
   HoraCorrente=HoraCorrente%86400;
   if(StopTime<StartTime)
   {
      //--- going past midnight
      if(HoraCorrente>=StartTime || HoraCorrente<StopTime)
      {
         return(true);
      }
   }
   else
   {
      //--- within one day
      if(HoraCorrente>=StartTime && HoraCorrente<StopTime)
      {
         return(true);
      }
   }
   return(false);
}

//---Limites-----------------------------------------------------------------------------

bool Limites(int limiteOPGain, int limiteRSGain, int limiteOPLoss, int limiteRSLoss)
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
   datetime vHora_Operacao = 0;
      
   for(int i = 0; i < vTotalOrdens; i++)
   {
      ulong vTicket = HistoryDealGetTicket(i);
      
      if(vTicket > 1)
      {
         vResultadoOperacao = HistoryDealGetDouble(vTicket, DEAL_PROFIT);
         vHora_Operacao = (datetime)HistoryDealGetInteger(vTicket,DEAL_TIME);         
         string vAtivo = HistoryDealGetString(vTicket,DEAL_SYMBOL);
         
         if ((vResultadoOperacao > 0) && (vAtivo != "") && (vAtivo != NULL))
         {
            vTotalGainOP = vTotalGainOP + 1;
            vTotalGainRS = vTotalGainRS + vResultadoOperacao;
            vTotalLossOP = 0;   
         }         
         else if ((vResultadoOperacao < 0) && (vAtivo != "") && (vAtivo != NULL))
         {
            vTotalLossOP = vTotalLossOP + 1;
            vTotalLossRS = vTotalLossRS - (vResultadoOperacao * (-1));
             
         }
         
         if ((vTotalGainOP == limiteOPGain) || 
            ((vTotalGainRS + vTotalLossRS) > limiteRSGain) ||
             (vTotalLossOP == limiteOPLoss) ||
           (((vTotalGainRS + vTotalLossRS) * (-1)) > limiteRSLoss))
         {
            return(true); 
         }  
      }
   }																			 
   return(false);
}