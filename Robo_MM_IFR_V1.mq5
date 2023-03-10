//+------------------------------------------------------------------+
//|                                                  Robo_MM_IFR.mq5 |
//|                                             rafaelfvcs@gmail.com |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "antoniokucas@hotmail.com"
#property link      "https://www.mql5.com"
#property version   "1.2"
//---
enum ESTRATEGIA_ENTRADA
  {
   APENAS_MM,  // Apenas Médias Móveis
   APENAS_IFR, // Apenas IFR
   MM_E_IFR    // Médias mais IFR
  };
//---

// Variáveis Input
sinput string s0; //-----------Estratégia de Entrada-------------
input ESTRATEGIA_ENTRADA   estrategia      = APENAS_MM;     // Estratégia de Entrada Trader

sinput string s1; //-----------Médias Móveis-------------
input int mm_rapida_periodo                = 09;            // Periodo Média Rápida
input int mm_lenta_periodo                 = 21;            // Periodo Média Lenta
input ENUM_TIMEFRAMES mm_tempo_grafico     = PERIOD_CURRENT;// Tempo Gráfico
input ENUM_MA_METHOD  mm_metodo            = MODE_SMA;      // Método 
input ENUM_APPLIED_PRICE  mm_preco         = PRICE_CLOSE;   // Preço Aplicado

sinput string s2; //-----------IFR-------------
input int ifr_periodo                      = 5;             // Período IFR
input ENUM_TIMEFRAMES ifr_tempo_grafico    = PERIOD_CURRENT;// Tempo Gráfico  
input ENUM_APPLIED_PRICE ifr_preco         = PRICE_CLOSE;   // Preço Aplicado

input int ifr_sobrecompra                  = 70;            // Nível de Sobrecompra
input int ifr_sobrevenda                   = 30;            // Nível de Sobrevenda

sinput string s3; //---------------------------
input float num_lots                       = 0.1;           // Número de Lotes
input double TK                            = 60;            // Take Profit
input double SL                            = 30;            // Stop Loss

sinput string s4; //---------------------------
input string hora_limite_fecha_op          = "16:30";       // Horário Limite Fechar Posição 
//---
//+------------------------------------------------------------------+
//|  Variáveis para os indicadores                                   |
//+------------------------------------------------------------------+

int mm_rapida_Handle;      
double mm_rapida_Buffer[]; 

int mm_lenta_Handle;      
double mm_lenta_Buffer[]; //

int ifr_Handle;           
double ifr_Buffer[];      

//+------------------------------------------------------------------+
//| Variáveis para as funçoes                                        |
//+------------------------------------------------------------------+

int magic_number = 123456;   

MqlRates velas[];            
MqlTick tick;                

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   mm_rapida_Handle = iMA(_Symbol,mm_tempo_grafico,mm_rapida_periodo,0,mm_metodo,mm_preco);
   mm_lenta_Handle  = iMA(_Symbol,mm_tempo_grafico,mm_lenta_periodo,0,mm_metodo,mm_preco);
   
   ifr_Handle = iRSI(_Symbol,ifr_tempo_grafico,ifr_periodo,ifr_preco);
   
   if(mm_rapida_Handle<0 || mm_lenta_Handle<0 || ifr_Handle<0)
     {
      Alert("Erro ao tentar criar Handles para o indicador - erro: ",GetLastError(),"!");
      return(-1);
     }
   
   CopyRates(_Symbol,_Period,0,4,velas);
   ArraySetAsSeries(velas,true);
   
   // Adiciona os indicadores
   ChartIndicatorAdd(0,0,mm_rapida_Handle); 
   ChartIndicatorAdd(0,0,mm_lenta_Handle);
   ChartIndicatorAdd(0,1,ifr_Handle);
   //---
//---
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
//---
   IndicatorRelease(mm_rapida_Handle);
   IndicatorRelease(mm_lenta_Handle);
   IndicatorRelease(ifr_Handle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
  
    CopyBuffer(mm_rapida_Handle,0,0,4,mm_rapida_Buffer);
    CopyBuffer(mm_lenta_Handle,0,0,4,mm_lenta_Buffer);
    
    CopyBuffer(ifr_Handle,0,0,4,ifr_Buffer);
    
    CopyRates(_Symbol,_Period,0,4,velas);
    ArraySetAsSeries(velas,true);
    
    ArraySetAsSeries(mm_rapida_Buffer,true);
    ArraySetAsSeries(mm_lenta_Buffer,true);
    ArraySetAsSeries(ifr_Buffer,true);
    //---
    

    SymbolInfoTick(_Symbol,tick);
   
    // Lógica da compra
    bool compra_mm_cros = mm_rapida_Buffer[0] > mm_lenta_Buffer[0] &&
                          mm_rapida_Buffer[2] < mm_lenta_Buffer[2] ;
                                             
    bool compra_ifr = ifr_Buffer[0] <= ifr_sobrevenda;
    
    // Lógica de venda
    bool venda_mm_cros = mm_lenta_Buffer[0] > mm_rapida_Buffer[0] &&
                         mm_lenta_Buffer[2] < mm_rapida_Buffer[2];
    
    bool venda_ifr = ifr_Buffer[0] >= ifr_sobrecompra;
   
   //---
    bool Comprar = false; 
    bool Vender  = false; 
    
    if(estrategia == APENAS_MM)
      {
       Comprar = compra_mm_cros;
       Vender  = venda_mm_cros;
       
      }
    else if(estrategia == APENAS_IFR)
     {
        Comprar = compra_ifr;
        Vender  = venda_ifr;
     }
    else
      {
         Comprar = compra_mm_cros && compra_ifr;
         Vender  = venda_mm_cros && venda_ifr;
      } 
   
   //---
   // retorna true se tivermos uma nova vela
    bool temosNovaVela = TemosNovaVela(); 
    
    if(temosNovaVela)
      {
       
       // Condição de Compra:
       if(Comprar && PositionSelect(_Symbol)==false)
         {
          desenhaLinhaVertical("Compra",velas[1].time,clrBlue);
          CompraAMercado();
         }
       
       // Condição de Venda:
       if(Vender && PositionSelect(_Symbol)==false)
         {
          desenhaLinhaVertical("Venda",velas[1].time,clrRed);
          VendaAMercado();
         } 
         
      }
    
    //---
     if(TimeToString(TimeCurrent(),TIME_MINUTES) == hora_limite_fecha_op && PositionSelect(_Symbol)==true)
        {
            Print("-----> Fim do Tempo Operacional: encerrar posições abertas!");
             
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               {
                  FechaCompra();
               }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               {
                  FechaVenda();
               }
        }  
   
  }
//+------------------------------------------------------------------+


void desenhaLinhaVertical(string nome, datetime dt, color cor = clrBlueViolet)
   {
      ObjectDelete(0,nome);
      ObjectCreate(0,nome,OBJ_VLINE,0,dt,0);
      ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
   } 
//---

//+------------------------------------------------------------------+
//| FUNÇÕES PARA ENVIO DE ORDENS                                     |
//+------------------------------------------------------------------+

// COMPRA A MERCADO
void CompraAMercado() 
  {
   MqlTradeRequest   requisicao;    // requisição
   MqlTradeResult    resposta;      // resposta
   
   ZeroMemory(requisicao);
   ZeroMemory(resposta);
   
   //--- Cacacterísticas da ordem de Compra
   requisicao.action       = TRADE_ACTION_DEAL;                            // Executa ordem a mercado
   requisicao.magic        = magic_number;                                 // Nº mágico da ordem
   requisicao.symbol       = _Symbol;                                      // Simbolo do ativo
   requisicao.volume       = num_lots;                                     // Nº de Lotes
   requisicao.price        = NormalizeDouble(tick.ask,_Digits);            // Preço para a compra
   requisicao.sl           = NormalizeDouble(tick.ask - SL*_Point,_Digits);// Preço Stop Loss
   requisicao.tp           = NormalizeDouble(tick.ask + TK*_Point,_Digits);// Alvo de Ganho - Take Profit
   requisicao.deviation    = 0;                                            // Desvio Permitido do preço
   requisicao.type         = ORDER_TYPE_BUY;                               // Tipo da Ordem
   requisicao.type_filling = ORDER_FILLING_FOK;                            // Tipo deo Preenchimento da ordem
   
   //---
   OrderSend(requisicao,resposta);
   //---
   if(resposta.retcode == 10008 || resposta.retcode == 10009)
     {
      Print("Ordem de Compra executada com sucesso!");
     }
   else
     {
       Print("Erro ao enviar Ordem Compra. Erro = ", GetLastError());
       ResetLastError();
     }
  }

// VENDA A MERCADO
void VendaAMercado()
  {
   MqlTradeRequest   requisicao;   
   MqlTradeResult    resposta;   
   
   ZeroMemory(requisicao);
   ZeroMemory(resposta);
   
   //--- Cacacterísticas da ordem de Venda
   requisicao.action       = TRADE_ACTION_DEAL;                            // Executa ordem a mercado
   requisicao.magic        = magic_number;                                 // Nº mágico da ordem
   requisicao.symbol       = _Symbol;                                      // Simbolo do ativo
   requisicao.volume       = num_lots;                                     // Nº de Lotes
   requisicao.price        = NormalizeDouble(tick.bid,_Digits);            // Preço para Venda
   requisicao.sl           = NormalizeDouble(tick.bid + SL*_Point,_Digits);// Preço Stop Loss
   requisicao.tp           = NormalizeDouble(tick.bid - TK*_Point,_Digits);// Alvo de Ganho - Take Profit
   requisicao.deviation    = 0;                                            // Desvio Permitido do preço
   requisicao.type         = ORDER_TYPE_SELL;                              // Tipo da Ordem
   requisicao.type_filling = ORDER_FILLING_FOK;                            // Tipo deo Preenchimento da ordem
   //---
   OrderSend(requisicao,resposta);
   //---
     if(resposta.retcode == 10008 || resposta.retcode == 10009)
       {
        Print("Ordem de Venda executada com sucesso!");
       }
     else
       {
        Print("Erro ao enviar Ordem Venda. Erro = ", GetLastError());
        ResetLastError();
       } 
 }
//---
//---
void FechaCompra()
   {
      MqlTradeRequest   requisicao;    // requisição
      MqlTradeResult    resposta;      // resposta
      
      ZeroMemory(requisicao);
      ZeroMemory(resposta);
      
      //--- Cacacterísticas da ordem de Venda
      requisicao.action       = TRADE_ACTION_DEAL;
      requisicao.magic        = magic_number;
      requisicao.symbol       = _Symbol;
      requisicao.volume       = num_lots; 
      requisicao.price        = 0; 
      requisicao.type         = ORDER_TYPE_SELL;
      requisicao.type_filling = ORDER_FILLING_RETURN;
      
      //---
      OrderSend(requisicao,resposta);
      //---
        if(resposta.retcode == 10008 || resposta.retcode == 10009)
          {
           Print("Ordem de Venda executada com sucesso!");
          }
        else
          {
           Print("Erro ao enviar Ordem Venda. Erro = ", GetLastError());
           ResetLastError();
          }
   }

void FechaVenda()
   {   
      MqlTradeRequest   requisicao;    // requisição
      MqlTradeResult    resposta;      // resposta
      
      ZeroMemory(requisicao);
      ZeroMemory(resposta);
      
      //--- Cacacterísticas da ordem de Compra
      requisicao.action       = TRADE_ACTION_DEAL;
      requisicao.magic        = magic_number;
      requisicao.symbol       = _Symbol;
      requisicao.volume       = num_lots; 
      requisicao.price        = 0; 
      requisicao.type         = ORDER_TYPE_BUY;
      requisicao.type_filling = ORDER_FILLING_RETURN;
      
      //---
      OrderSend(requisicao,resposta);
   
      //---
        if(resposta.retcode == 10008 || resposta.retcode == 10009)
          {
           Print("Ordem de Compra executada com sucesso!");
          }
        else
          {
           Print("Erro ao enviar Ordem Compra. Erro = ", GetLastError());
           ResetLastError();
          }
   }
//---
//+------------------------------------------------------------------+
//| FUNÇÕES ÚTEIS                                                    |
//+------------------------------------------------------------------+
//--- Para Mudança de Candle
bool TemosNovaVela()
  {
//--- memoriza o tempo de abertura da ultima barra (vela) numa variável
   static datetime last_time=0;
//--- tempo atual
   datetime lastbar_time= (datetime) SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);

//--- se for a primeira chamada da função:
   if(last_time==0)
     {
      //--- atribuir valor temporal e sair
      last_time=lastbar_time;
      return(false);
     }

//--- se o tempo estiver diferente:
   if(last_time!=lastbar_time)
     {
      //--- memorizar esse tempo e retornar true
      last_time=lastbar_time;
      return(true);
     }
//--- se passarmos desta linha, então a barra não é nova; retornar false
   return(false);
  }   
   