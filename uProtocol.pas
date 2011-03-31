// -----------------------------------------------------------------------------
//  Protokollimplementation für die EE-Brettspiel-KI-Challenge
//                                        - (C) 2011 by Martok
//  v1.0 vom 2011-03-13 - Martok
//    - erste funktionierende Version
//  v1.01 vom 2011-03-16 - Martok
//    - Schleife für Zuggenerierung durch Callback ersetzt
//    - Koordinatenumrechnung in separaten Funktionen
//    - Zugberechnung in extern aufrufbare Funktion
//  v1.02 vom 2011-03-19 - Martok
//    - Anpassung an Protokollversion 2 (endSession, GS, session_number)
//  v1.03 vom 2011-03-23 - Martok
//    - Anpassung an Protokollversion 3 (getActionsLong)
// -----------------------------------------------------------------------------


unit uProtocol;

interface

uses
  SysUtils, Classes, Contnrs, IdTCPConnection, IdHTTP;

const
  // Protokollversion, muss von Client+Server identisch sein
  SUPPORTED_SERVER_VERSION = 3;

type
  // Allgemeine Klasse für alle ERR:-Antworten
  EProtocolException = class(Exception);

  // Das Brett selbst kennt nur "ich" und "der andere", die Farbe ist eigentlich irrelevant
  TPlayerColor = (White, Black);
  TField = (Empty, Blocked, ThisPlayer, OtherPlayer);
  TColIndex = 'a'..'i';
  TRowIndex = 1..9;
  TFieldCoord = String[2];
  TBoard = array[TColIndex, TRowIndex] of TField;

  TNetGameProtocol = class;
  TNetGameClass = class of TNetGame;
  {
     TNetGame
     Abstrakte Basisklasse für alle Spiel-Clients/Bots
     Definiert das allgemeine Verhalten und einige funktionen, die in abgeleiten
     Klassen überschrieben werden müssen.
  }
  TNetGame = class
  private
    FOwner: TNetGameProtocol;
    FGameID: integer;
  protected
    // Das aktuelle Brett. Indiziert a..i,1..9
    Board: TBoard;
    // Meine Farbe, z.B. zum Zeichnen oder für Logs
    PlayerColor: TPlayerColor;
    // Name des Gegner-Clients
    OpponentName: string;
    // Zug auf dem Brett ausführen
    procedure MapMove(F,T: TFieldCoord; Pl: TField);
    // Nächsten Zug anfordern
    procedure QueryNextMove;
  public
    constructor Create(AOwner: TNetGameProtocol; AGameID: integer);
    destructor Destroy; override;
    // GAME_ID dieses Spiels
    property ID: integer read FGameID;

    // Handler-Methoden für die ACTIONs...
    // ... gs
    procedure ActionGameStarted(MyColor: TPlayerColor; Opponent: string; BlockedFields: TStringList);
    // ... mv
    procedure ActionMoved(FieldFrom, FieldTo: TFieldCoord; MyMoveNext: boolean);
    // ... ge
    procedure ActionGameEnded(DidIWin: boolean);
    // ... ga
    procedure ActionGameAborted;

    // Zug ausführen. Meldet der Server einen Fehler, wird eine EProtocolException ausgelöst
    // Result: true wenn Gegner passen muss (= man direkt wieder dran ist)
    function Move(FieldFrom, FieldTo: TFieldCoord): boolean;

    {
      Die folgenden Methoden müssen von Bots überschrieben ('override') werden.
      Sie werden vom Code an passender Stelle aufgerufen und es wird erwartet,
      dass die Reaktion exakt nach den Regeln erfolgt.
    }
    // Result: Von der Spielleitung zugeteilter Name des Clients zur Identifikation
    class function ClientName: string; virtual; abstract;
    // Result: Von der Spielleitung zugeteilter geheimer Schlüssel
    class function ClientSecret: string; virtual; abstract;
    // Der nächste Zug ist nötig. Innerhalbt dieser Methode muss *genau einmal* .Move auferufen werden.
    procedure NextMove; virtual; abstract;
    // Ein Zug wurde gemacht. Das Board hat jetzt schon den neuen Zustand
    // OPTIONAL, Standardverhalten: nichts.
    //   FieldFrom: Ursprungsfeld
    //   FieldTo: Ursprungsfeld
    //   MovingPlayer: (ThisPlayer, OtherPlayer) Wer hat gezogen?
    procedure AfterMove(FieldFrom, FieldTo: TFieldCoord; MovingPlayer: TField); virtual;
    // Das Spiel ist gestartet, alle Vorbereitungen sind abgeschlossen.
    // OPTIONAL, Standardverhalten: nichts.
    procedure GameStart; virtual;
    // Das Spiel ist beendet
    //   RegularEnd: Wurde das Ende durch Sieg/Niederlage (true) oder irregulär abgebrochen (false)?
    //   DidIWin: Hat dieser Client gewonnen (true) oder verloren (false)?
    procedure GameEnd(RegularEnd, DidIWin: boolean); virtual; abstract;
  end;

  TLPThread = class(TThread)
  private
    FPA: TNetGameProtocol;
    FResult: string;
    http: TIdHTTP;
    procedure SyncCallback;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TNetGameProtocol);
    procedure EndMe;
  end;

  // Allgemeine Informationen über verfügbare Spiele
  TReplayHeader = record
    // Unter welcher ID ist das Spiel gelaufen
    GameID: integer;
    // Welcher Client hat welche Seite gespielt?
    White,
    Black: string;
    // Wann wurde es gestartet
    StartTime: TDateTime;
  end;
  TReplayList = array of TReplayHeader;

  // Ein Zug in einem Spiel.
  //   Ist das ein Aussetzen-'Zug', ist DateTime=0 und FieldFrom=FieldTo=''
  TReplayMove = record
    // Wann wurde der Zug gemacht?
    DateTime: TDateTime;
    // Von welchem Feld
    FieldFrom,
    // Zu welchem Feld?
    FieldTo: TFieldCoord;
  end;
  // Alle Züge hintereinander, Index 0 ist dementsprechend der erste Zug den Schwarz
  // gemacht hat, Index 1 der erste von Weiß
  TReplayGame = array of TReplayMove;

  TNetGameProtocol = class
  private
    http: TIdHTTP;
    FGameClass: TNetGameClass;
    LPThread: TLPThread; 
  protected
    FBaseURL: string;
    FSessionId: string;
    FServerVersion: integer;
    FGames: TObjectList;
    procedure ParseAction(Action: string);
    procedure DoHandleAction(ID: string; Data: TStringList);
    function DoMove(Game: TNetGame; FieldFrom, FieldTo: TFieldCoord): boolean;
  public
    // Konstruktor.
    //   BaseURL: Wo ist der Server? Inklusive HTTP, ohne ? am Ende: 'http://example.com/game.php'
    constructor Create(BaseURL: string);
    destructor Destroy; override;

    // Ohne Session möglich: Replays abfragen
    // Zum Datenformat siehe Kommentare in den TReplay*-Typen
    procedure GetReplayList(out Listing: TReplayList);
    procedure GetReplayGameData(GameID: integer; out Game: TReplayGame);

    // Session eröffnen. Darf nur einmal aufgerufen werden.
    //   AGameClass: Zu verwendende Client-Klasse
    procedure CreateSession(AGameClass: TNetGameClass);
    // Session eröffnen. Darf nur einmal aufgerufen werden.
    // !!!! Kein weiterer irgendeiner Funktion danach möglich, alle Referenzen
    //         auf Spiele-Instanzen werden hierdurch ungültig             !!!!
    procedure EndSession;
    property SessionId: string read FSessionId;

    // auf auszuführende Aktionen pollen und ggf. an Spielinstanzen weiterleiten
    procedure GetActions;

    // LongPolling-Thread starten. Durch die verwendeten Indys ist das nicht
    // unbedingt eine tolle Idee, da diese einen Aufruf nicht unfallfrei abbrechen
    // können.
    // Soll es trotzdem verwendet werden, sollte in den Debugger-Optionen die
    // Exception EIdNotConnected ignoriert werden. Sie wird im Code korrekt
    // abgefangen, aber das ändert nichts daran dass Delphi sich im Debug-Modus
    // immer an dieser Stelle einschalten wird. 
    procedure EnableActionLoop;
    procedure DisableActionLoop;
    // Holt die Liste der Clients
    // In den Objects wird die session_number als integer abgelegt!
    procedure GetClientList(List: TStrings);
    // Spiel starten. Gibt die erzeugte Instanz zurück
    //   PartnerSN: die session_number aus der ClientList
    function StartGame(PartnerSN: Integer): TNetGame;
  end;

const
  cmd_startSession = '%s?mode=startSession&secret=%s&client=%s';
  cmd_endSession   = '%s?mode=endSession&session=%s';
  cmd_getActions   = '%s?mode=getActions&session=%s';
  cmd_getActionsLong= '%s?mode=getActionsLong&session=%s';
  cmd_listClients  = '%s?mode=listClients&session=%s';
  cmd_startGame    = '%s?mode=startGame&sessionNo=%d&session=%s';
  cmd_move         = '%s?mode=move&session=%s&game=%d&from=%s&to=%s';

  cmd_listReplays  = '%s?mode=listReplays';
  cmd_getReplay    = '%s?mode=getReplay&game=%d';

  errIncompatibleServer = 'Abgebrochen: Serverversion ist nicht kompatibel (%d, erwartet: %d)';
  errUnknownGame        = 'Unbekanntes Spiel: %d';
  errUnknownPlayerColor = 'Unbekannte Farbe: %s';
  errUnknownBoolChar    = 'Unbekannter Wahrheitswert: %s';

  
// Diese Routinen benutzen einiges an Typecasts, um teuere StrToInt/IntToStr zu sparen
function FieldCoordToColRow(const Field: TFieldCoord; out Col: TColIndex; out Row: TRowIndex): boolean;
function FieldCoordToNumeric(const Field: TFieldCoord; out Col, Row: byte): boolean;
function ColRowToFieldCoord(const Col: TColIndex; const Row: TRowIndex): TFieldCoord;
function NumericToFieldCoord(const Col, Row: byte): TFieldCoord;

// Wie weit sind diese Felder auseinander? (Chebyshev-Distanz)
function BoardDistance(FieldFrom, FieldTo: TFieldCoord): integer;
// gülitge Koordinaten? (Prüfung nach Datentyp)
function BoardValidCoords(C: TColIndex; R: TRowIndex): boolean;
// Führt einen Zug auf einem Board aus. ACHTUNG: es wird angenommen, dass Pl wirklich auf F steht
procedure BoardMapMove(var Board: TBoard; F, T: TFieldCoord; Pl: TField);
// Initialisiert das Brett für eine bestimmte Perspektive
procedure BoardMapInit(var Board: TBoard; Black, White: TField);


implementation

uses Math, DateUtils;

function SplitString(S:String; Delim: char): TStringList;
begin
  Result:= TStringList.Create;
  Result.Delimiter:= Delim;
  Result.DelimitedText:= S;
end;

function SubList(Source: TStringList; First, Last: integer): TStringList;
var i:integer;
begin
  Result:= TStringList.Create;
  if First>=Source.Count then exit;
  if Last>=Source.Count then Last:= Source.Count-1;
  for i:= First to Last do
    Result.AddObject(Source[i],Source.Objects[i]);
end;

// Parst nur das hier verwendete Format: YYYYMMDDHHNNSS
function ISODateToDateTime(const ISOString: string): TDateTime;
begin
  Result:= EncodeDateTime(StrToInt(Copy(ISOString,1,4)),
                          StrToInt(Copy(ISOString,5,2)),
                          StrToInt(Copy(ISOString,7,2)),
                          StrToInt(Copy(ISOString,9,2)),
                          StrToInt(Copy(ISOString,11,2)),
                          StrToInt(Copy(ISOString,13,2)),
                          0);
end;

procedure HandleErrorResult(ResultString: String);
begin
  if Copy(ResultString,1,4)='ERR:' then
    raise EProtocolException.Create(Copy(ResultString,5,Maxint));
end;

function CharToPlayerColor(Letter:Char): TPlayerColor;
begin
  case Letter of
    'w': Result:= White;
    'b': Result:= Black;
  else
    raise EProtocolException.CreateFmt(errUnknownPlayerColor,[Letter]);
  end;
end;

function CharToBoolean(Letter:Char): Boolean;
begin
  case Letter of
    'y': Result:= True;
    'n': Result:= False;
  else
    raise EProtocolException.CreateFmt(errUnknownBoolChar,[Letter]);
  end;
end;

function FieldCoordToColRow(const Field: TFieldCoord; out Col: TColIndex; out Row: TRowIndex): boolean;
begin
  Result:= (Field[1] in [low(TColIndex)..high(TColIndex)]) and ((Ord(Field[2])-Ord('0')) in [low(TRowIndex)..high(TRowIndex)]);
  if Result then begin
    Col:= Field[1];
    Row:= TRowIndex(Ord(Field[2])-Ord('0'));
  end;
end;

function FieldCoordToNumeric(const Field: TFieldCoord; out Col, Row: byte): boolean;
begin
  Result:= (Field[1] in [low(TColIndex)..high(TColIndex)]) and ((Ord(Field[2])-Ord('0')) in [low(TRowIndex)..high(TRowIndex)]);
  if Result then begin
    Col:= ord(Field[1])-ord(low(TColIndex));
    Row:= ord(Field[2])-Ord('0')-ord(low(TRowIndex));
  end;
end;

function ColRowToFieldCoord(const Col: TColIndex; const Row: TRowIndex): TFieldCoord;
begin
  SetLength(Result,2);
  Result[1]:= Col;
  Result[2]:= AnsiChar(Row + Ord('0')); 
end;

function NumericToFieldCoord(const Col, Row: byte): TFieldCoord;
begin
  SetLength(Result,2);
  Result[1]:= AnsiChar(Ord(low(TColIndex)) + Col);
  Result[2]:= AnsiChar(Ord(low(TRowIndex)) + Row + Ord('0'));
end;

function BoardDistance(FieldFrom, FieldTo: TFieldCoord): integer;
var r1,c1,r2,c2: byte;
begin
  Result:= -1;
  if FieldCoordToNumeric(FieldFrom,c1,r1) and FieldCoordToNumeric(FieldTo,c2,r2) then begin
    if c1=c2 then                          // vertikal
      Result:= Abs(r2-r1)
    else
    if r1=r2 then                          // horizontal
      Result:= Abs(c2-c1)
    else
    if Abs(r2-r1) = Abs(c2-c1) then        // diagonal
      Result:= Abs(c2-c1);
  end;                                     // alles andere ist -1 -> invalid move
end;

function BoardValidCoords(C: TColIndex; R: TRowIndex): boolean;
begin
  Result:= (r in [low(r)..high(r)]) and (c in [low(c)..high(c)]);
end;

procedure BoardMapMove(var Board: TBoard; F, T: TFieldCoord; Pl: TField);
var r: TRowIndex;
    c: TColIndex;
  procedure ConvertAt(cc: TColIndex; rr: TRowIndex);
  begin
    if (rr in [low(r)..high(r)]) then begin
      if (Board[cc,rr] in [ThisPlayer, OtherPlayer]) and (Board[cc,rr]<>Pl) then
        Board[cc,rr]:= Pl;
    end;
  end;

begin
  FieldCoordToColRow(T,c,r);
  Board[c,r]:= Pl;

//Nach dem Zug werden alle feindlichen Steine, die auf an das Zielfeld grenzenden Feldern liegen,
//zur Farbe des Spielers konvertiert.
  if c>low(c) then begin
    ConvertAt(pred(c),pred(r));
    ConvertAt(pred(c),r);
    ConvertAt(pred(c),succ(r));
  end;
  if c<high(c) then begin
    ConvertAt(succ(c),pred(r));
    ConvertAt(succ(c),r);
    ConvertAt(succ(c),succ(r));
  end;
  ConvertAt(c,pred(r));
  ConvertAt(c,succ(r));

  // muss der alte weg?
  // 1 Feld: kopiert
  // 2 Felder: verschoben
  if BoardDistance(F, T)=2 then begin
    FieldCoordToColRow(F,c,r);
    Board[c,r]:= Empty;
  end;
end;

procedure BoardMapInit(var Board: TBoard; Black, White: TField);
begin
  Board['a',1]:= White;
  Board['i',9]:= White;
  Board['a',9]:= Black;
  Board['i',1]:= Black;
end;




{ TNetGameProtocol }

constructor TNetGameProtocol.Create(BaseURL: string);
begin
  inherited Create;
  http:= TIdHTTP.Create(nil);
  FBaseURL:= BaseURL;
  FGames:= TObjectList.Create(true);
  FSessionId:= '';
end;

destructor TNetGameProtocol.Destroy;
begin
  DisableActionLoop;
  FreeAndNil(FGames);
  FreeAndNil(http);
  inherited;
end;

procedure TNetGameProtocol.CreateSession(AGameClass: TNetGameClass);
var s:string;
    data: TStringList;
begin
  if FSessionId>'' then
    exit;
  s:= http.Get(format(cmd_startSession,[FBaseURL, AGameClass.ClientSecret, AGameClass.ClientName]));
  HandleErrorResult(s);
  data:= SplitString(S,',');
  try
    FSessionId:= data[0];
    FServerVersion:= StrToInt(data[1]);
    FGameClass:= AGameClass;
    if FServerVersion<>SUPPORTED_SERVER_VERSION then
      raise EProtocolException.CreateFmt(errIncompatibleServer,[FServerVersion,SUPPORTED_SERVER_VERSION]);
  finally
    data.Free;
  end;
end;

procedure TNetGameProtocol.EndSession;
var s:string;
begin
  if FSessionId='' then
    exit;
  s:= http.Get(format(cmd_endSession,[FBaseURL, FSessionId]));
  HandleErrorResult(s);
  FGames.Clear;
  FSessionId:= '';
end;

procedure TNetGameProtocol.GetActions;
var s:string;
    data: TStringList;
    i: integer;
begin
  s:= http.Get(format(cmd_getActions,[FBaseURL, FSessionId]));
  HandleErrorResult(s);
  data:= SplitString(S,';');
  try
    for i:= 0 to data.count-1 do
      ParseAction(data[i]);
  finally
    data.Free;
  end;
end;

procedure TNetGameProtocol.ParseAction(Action: string);
var info,data: TStringList;
begin
  info:= SplitString(Action,':');
  try
    data:= SplitString(info[1],',');
    try
      DoHandleAction(info[0],data);
    finally
      data.Free;
    end;
  finally
    info.Free;
  end;
end;

procedure TNetGameProtocol.DoHandleAction(ID: string; Data: TStringList);
var game: TNetGame;
    gid,i: integer;
    ls: TStringList;
begin
  game:= nil;
  gid:= StrToInt(Data[0]);
  // bekanntes Spiel?
  for i:= 0 to FGames.Count-1 do
    if TNetGame(FGames[i]).ID=gid then begin
      game:= TNetGame(FGames[i]);
      break;
    end;
  if not Assigned(game) then begin
    // wir wurden frisch herausgefordert, das sollte ein 'gs' sein
    Game:= FGameClass.Create(Self, gid);
    FGames.Add(Game);
  end;

  if id='gs' then begin
    ls:= SubList(Data,3,MaxInt);
    try
      game.ActionGameStarted(CharToPlayerColor(Data[1][1]),Data[2],ls);
    finally
      ls.Free;
    end;
  end else
  if id='mv' then begin
    game.ActionMoved(Data[1],Data[2],CharToBoolean(Data[3][1]));
  end else
  if id='ge' then begin
    game.ActionGameEnded(Data[1]='w');
    FGames.Remove(game);
  end else
  if id='ga' then begin
    game.ActionGameAborted;
    FGames.Remove(game);
  end;
end;

procedure TNetGameProtocol.GetClientList(List: TStrings);
var s:string;
    data,sent: TStringList;
    i:integer;
begin
  s:= http.Get(format(cmd_listClients,[FBaseURL, FSessionId]));
  HandleErrorResult(s);
  data:= SplitString(S,';');
  try
    List.Clear;
    for i:= 0 to Data.Count-1 do begin
      sent:= SplitString(data[i],',');
      List.AddObject(sent[1],Pointer(StrToInt(sent[0])));
    end;
  finally
    data.Free;
  end;
end;

function TNetGameProtocol.StartGame(PartnerSN: Integer): TNetGame;
var s:string;
    data: TStringList;
begin
  s:= http.Get(format(cmd_startGame,[FBaseURL, PartnerSN, FSessionId]));
  HandleErrorResult(s);
  data:= SplitString(S,',');
  try
    Result:= FGameClass.Create(Self, StrToInt(data[0]));
    FGames.Add(Result);
  finally
    data.Free;
  end;
end;

function TNetGameProtocol.DoMove(Game: TNetGame; FieldFrom, FieldTo: TFieldCoord): boolean;
var s:string;
    data: TStringList;
begin
  s:= http.Get(format(cmd_move,[FBaseURL, FSessionId, Game.ID, FieldFrom, FieldTo]));
  HandleErrorResult(s);
  data:= SplitString(S,',');
  try
    Result:= CharToBoolean(data[0][1]);
  finally
    data.Free;
  end;
end;

procedure TNetGameProtocol.GetReplayList(out Listing: TReplayList);
var s:string;
    data,rp: TStringList;
    i: integer;
begin
  SetLength(Listing,0);
  s:= http.Get(format(cmd_listReplays,[FBaseURL]));
  HandleErrorResult(s);
  data:= SplitString(S,';');
  try
    SetLength(Listing,Data.Count);
    for i:= 0 to data.Count-1 do begin
      rp:= SplitString(data[i],',');
      try
        Listing[i].GameID:= StrToInt(rp[0]);
        Listing[i].Black:= rp[1];
        Listing[i].White:= rp[2];
        Listing[i].StartTime:= ISODateToDateTime(rp[3]);
      finally
        rp.Free;
      end;
    end;
  finally
    data.Free;
  end;
end;

procedure TNetGameProtocol.GetReplayGameData(GameID: integer; out Game: TReplayGame);
var s:string;
    data,rp: TStringList;
    i: integer;
begin
  SetLength(Game,0);
  s:= http.Get(format(cmd_getReplay,[FBaseURL, GameID]));
  HandleErrorResult(s);
  data:= SplitString(S,';');
  try
    SetLength(Game,Data.Count);
    for i:= 0 to data.Count-1 do begin
      if data[i]>'' then begin
        rp:= SplitString(data[i],',');
        try
          Game[i].DateTime:= ISODateToDateTime(rp[0]);
          Game[i].FieldFrom:= rp[1];
          Game[i].FieldTo:= rp[2];
        finally
          rp.Free;
        end;
      end else begin
        Game[i].DateTime:= 0;
        Game[i].FieldFrom:= '';
        Game[i].FieldTo:= '';
      end;
    end;
  finally
    data.Free;
  end;
end;

procedure TNetGameProtocol.EnableActionLoop;
begin
  if not Assigned(LPThread) then begin
    LPThread:= TLPThread.Create(Self);
  end;
end;

procedure TNetGameProtocol.DisableActionLoop;
begin
  if Assigned(LPThread) then begin
    LPThread.EndMe;
    LPThread:= nil;
  end;
end;

{ TLPThread }

constructor TLPThread.Create(AOwner: TNetGameProtocol);
begin
  inherited Create(false);
  FPA:= AOwner;
  FreeOnTerminate:= true;
end;

procedure TLPThread.EndMe;
begin
  FPA:= nil;
  // damit bricht .Get ab
  http.IOHandler:= nil;
  Terminate;
end;

procedure TLPThread.Execute;
begin
  http:= TIdHTTP.Create(nil);
  try
    http.IOHandler:= nil;
    while not Terminated do begin
      try
        FResult:= http.Get(format(cmd_getActionsLong,[FPA.FBaseURL, FPA.FSessionId]));
      except
        on E: EIdNotConnected do ;
        else raise;
      end;
      if Assigned(FPA) then
        Synchronize(SyncCallback);
    end;
  finally
    FreeAndNil(http);
  end;
end;

procedure TLPThread.SyncCallback;
var data: TStringList;
    i: Integer;
begin
  HandleErrorResult(FResult);
  data:= SplitString(FResult,';');
  try
    for i:= 0 to data.count-1 do
      FPA.ParseAction(data[i]);
  finally
    data.Free;
  end;
end;

{ TNetGame }

constructor TNetGame.Create(AOwner: TNetGameProtocol; AGameID: integer);
begin
  inherited Create;
  FOwner:= AOwner;
  FGameID:= AGameID;
end;

destructor TNetGame.Destroy;
begin
  inherited;
end;

function TNetGame.Move(FieldFrom, FieldTo: TFieldCoord): boolean;
begin
  Result:= FOwner.DoMove(Self, FieldFrom, FieldTo);
  // Keine Exception geworfen? Wunderbar, dann Änderung übernehmen
  MapMove(FieldFrom,FieldTo,ThisPlayer);
end;

procedure TNetGame.ActionGameStarted(MyColor: TPlayerColor; Opponent: string;
  BlockedFields: TStringList);
var c: TColIndex;
    r: TRowIndex;
    bl,wh: TField;
begin
  for r:= low(r) to high(r) do
    for c:= low(c) to high(c) do begin
      if BlockedFields.IndexOf(ColRowToFieldCoord(c,r))>=0 then
        Board[c,r]:= Blocked
      else
        Board[c,r]:= Empty;
    end;
  PlayerColor:= MyColor;
  OpponentName:= Opponent;
  if PlayerColor=White then begin
    wh:= ThisPlayer;
    bl:= OtherPlayer;
  end else begin
    bl:= ThisPlayer;
    wh:= OtherPlayer;
  end;
  BoardMapInit(Board, bl,wh);
  GameStart;
  if PlayerColor=Black then
    QueryNextMove;
end;

procedure TNetGame.ActionMoved(FieldFrom, FieldTo: TFieldCoord; MyMoveNext: boolean);
begin
  MapMove(FieldFrom, FieldTo, OtherPlayer);
  if MyMoveNext then
    QueryNextMove;
end;

procedure TNetGame.QueryNextMove;
begin
  // ACHTUNG: von hier gehts auf dem Stack immer tiefer. Hoffentlich sind wir
  // nicht allzu oft hintereinander dran.
  NextMove;
end;

procedure TNetGame.MapMove(F, T: TFieldCoord; Pl: TField);
begin
  BoardMapMove(Board, F,T,Pl);
  AfterMove(F,T,Pl);
end;

procedure TNetGame.ActionGameAborted;
begin
  GameEnd(false, false);
end;

procedure TNetGame.ActionGameEnded(DidIWin: boolean);
begin
  GameEnd(true, DidIWin);
end;

procedure TNetGame.AfterMove(FieldFrom, FieldTo: TFieldCoord; MovingPlayer: TField);
begin end;

procedure TNetGame.GameStart;
begin end;

end.
