unit uClient;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, uProtocol, Grids, StdCtrls, ExtCtrls, DUStrings;

type
  TGameWindow = class(TForm)
    sgBoard: TStringGrid;
    meLog: TMemo;
    Panel1: TPanel;
    lbGameStat: TLabel;
    pnMakeMove: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    edMvFrom: TEdit;
    edMvTo: TEdit;
    Button1: TButton;
    procedure sgBoardDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure sgBoardSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure Button1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private-Deklarationen }
    Gm: TNetGame;
    ThisCol, OtherCol: TColor;
  public
    { Public-Deklarationen }
    procedure Magic(var Msg: TMessage); message WM_USER + 100;
  end;

  TScore = SmallInt;
const
  SCORE_MIN = -30000;
  SCORE_MAX =  30000;

type
  {
     TUIClient
     Hier gehts los: Unser Bot! Und da es kein Bot ist, heißt er UIClient.
  }
  TUIClient = class(TNetGame)
  private
    // Das Statusfenster AKA unser GUI.
    // Ja, ich werde da direkt drauf zugreifen. Kein guter Stil, aber dadurch
    // sieht man alles was passiert direkt im Bot-Code ;-)
    FStatusWindow: TGameWindow;
    procedure DrawBoard;
  public
    // Alles was man überschreiben muss
    // Wir nehmen auch die Optionalen, um ein Log schreiben zu können und das UI
    // passend zu aktualisieren
    class function ClientName: String; override;
    class function ClientSecret: String; override;
    procedure GameStart; override;
    procedure GameEnd(RegularEnd: Boolean; DidIWin: Boolean); override;
    procedure NextMove; override;
    procedure AfterMove(FieldFrom: TFieldCoord; FieldTo: TFieldCoord; MovingPlayer: TField); override;
    destructor Destroy; override;
  end;

  TUIClient2WithAI = class(TUIClient)
  public
    class function ClientName: String; override;
    procedure NextMove; override;

    function AIGetMove(out FF,FT: TFieldCoord): TScore;
  end;

  TUIClientWithAI = class(TUIClient2WithAI)
  public
    class function ClientName: String; override;
  end;

var
  GameWindow: TGameWindow;
  ThinkTime: integer = 5000;

implementation


{$R *.dfm}

{$I ClientSecret.inc.pas}

{ TUIClient }

class function TUIClient.ClientName: String;
begin
  Result:= 'MartokUIClient';
end;

class function TUIClient.ClientSecret: String;
begin
  Result:= ClientSecret_MartokUIClient;
end;

procedure TUIClient.GameEnd(RegularEnd, DidIWin: Boolean);
begin
  if RegularEnd then begin
    FStatusWindow.meLog.Lines.Add('Spiel beendet');
    if DidIWin then
      FStatusWindow.meLog.Lines.Add(' = Gewonnen = ')
    else
      FStatusWindow.meLog.Lines.Add(' = Verloren = ');
  end else
    FStatusWindow.meLog.Lines.Add('Spiel abgebrochen');
  FStatusWindow.Gm:= nil;
end;

procedure TUIClient.GameStart;
begin
  FStatusWindow:= TGameWindow.Create(Application);
  FStatusWindow.Caption:= ClientName+' - Spiel: '+IntToStr(ID);
  FStatusWindow.Show;
  FStatusWindow.pnMakeMove.Visible:= false;
  FStatusWindow.Gm:= Self;
  FStatusWindow.meLog.Clear;
  FStatusWindow.meLog.Lines.Add('Spiel gestartet');
  FStatusWindow.meLog.Lines.Add('T: '+ClientName);
  FStatusWindow.meLog.Lines.Add('O: '+OpponentName);
  if PlayerColor=White then begin
    FStatusWindow.ThisCol:= clSilver;
    FStatusWindow.OtherCol:= clBlack;
  end else begin
    FStatusWindow.ThisCol:= clBlack;
    FStatusWindow.OtherCol:= clSilver;
  end;
  DrawBoard;
end;

procedure TUIClient.NextMove;
begin
  FStatusWindow.pnMakeMove.Visible:= true;
  FStatusWindow.edMvFrom.Text:= '';
  FStatusWindow.edMvTo.Text:= '';
  // Hier warten wir jetzt auf User-Interaktion, die sich dann in Button1Click
  // niederschlagen wird.
end;

procedure TUIClient.AfterMove(FieldFrom, FieldTo: TFieldCoord; MovingPlayer: TField);
begin
  DrawBoard;
  case MovingPlayer of
    ThisPlayer  : FStatusWindow.meLog.Lines.Add('T: '+FieldFrom+' '+FieldTo);
    OtherPlayer : FStatusWindow.meLog.Lines.Add('O: '+FieldFrom+' '+FieldTo);
  end;
end;


procedure TUIClient.DrawBoard;
var r: TRowIndex;
    c: TColIndex;
    i,j:byte;
    th,ot,fl: integer;
begin
  th:= 0;
  ot:= 0;
  fl:= 0;
  for r:= low(r) to high(r) do
    for c:= low(c) to high(c) do begin
      FieldCoordToNumeric(ColRowToFieldCoord(c,r), i, j);
      if Board[c,r]=ThisPlayer then inc(th);
      if Board[c,r]=OtherPlayer then inc(ot);
      if Board[c,r]<>Blocked then inc(fl);
      FStatusWindow.sgBoard.Cells[i,j]:= IntToStr(Ord(Board[c,r]));
    end;
  FStatusWindow.lbGameStat.Caption:= Format('Eigene: %d Gegner: %d Felder: %d/81',[th,ot,fl]);
  FStatusWindow.sgBoard.Refresh;
end;

destructor TUIClient.Destroy;
begin
  if Assigned(FStatusWindow) then
    FStatusWindow.Gm:= nil;
  inherited;
end;

{ TUIClient2 }

class function TUIClient2WithAI.ClientName: String;
begin
  Result:= 'MartokUIClient2';
end;

{ TGameWindow }

procedure TGameWindow.sgBoardDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var s: string;
    f: TFieldCoord;
begin
  sgBoard.Canvas.Brush.Color:= clWindow;
  sgBoard.Canvas.FillRect(Rect);
  InflateRect(Rect,-2,-2);
  s:= sgBoard.Cells[ACol,ARow];
  if s='' then s:= '0';
  case TField(StrToInt(s)) of
    Empty: ;
    Blocked: begin
      sgBoard.Canvas.Pen.Color:= clBlue;
      sgBoard.Canvas.Brush.Color:= clBlue;
      sgBoard.Canvas.Rectangle(Rect);
    end;
    ThisPlayer:  begin
      sgBoard.Canvas.Pen.Color:= clRed;
      sgBoard.Canvas.Brush.Color:= ThisCol;
      sgBoard.Canvas.Ellipse(Rect);
    end;
    OtherPlayer: begin
      sgBoard.Canvas.Pen.Color:= OtherCol;
      sgBoard.Canvas.Brush.Color:= OtherCol;
      sgBoard.Canvas.Ellipse(Rect);
    end;
  end;
  f:= NumericToFieldCoord(ACol, ARow);
  sgBoard.Canvas.Brush.Color:= clMoneyGreen;
  sgBoard.Canvas.Font.Name:= 'Courier New';
  if ACol=0 then
    sgBoard.Canvas.TextOut(Rect.Left,Rect.Top+6,F[2]);
  if ACol=8 then
    sgBoard.Canvas.TextOut(Rect.Right-7,Rect.Top+6,F[2]);

  if ARow=0 then
    sgBoard.Canvas.TextOut(Rect.Left+12,Rect.Top,F[1]);
  if ARow=8 then
    sgBoard.Canvas.TextOut(Rect.Left+12,Rect.Bottom-11,F[1]);
end;

procedure TGameWindow.sgBoardSelectCell(Sender: TObject; ACol,
  ARow: Integer; var CanSelect: Boolean);
begin
  if edMvFrom.Text='' then
    edMvFrom.Text:= NumericToFieldCoord(ACol, ARow)
  else
  if edMvTo.Text='' then
    edMvTo.Text:= NumericToFieldCoord(ACol, ARow);
end;

procedure TGameWindow.Button1Click(Sender: TObject);
begin
  try
    if Gm.Move(edMvFrom.Text,edMvTo.Text) then    // Zug ausführen
      Gm.NextMove                                 // gleich nochmal oder...
    else
      pnMakeMove.Visible:= false;                 // ... erstmal fertig
  except
    edMvFrom.Text:= '';
    edMvTo.Text:= '';
    raise;
  end;
end;

procedure TGameWindow.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if Assigned(GM) then
    Action:= caNone
  else
    Action:= caFree;
end;

///
///   AI RELATED STUFF BELOW THIS LINE
/// ----------------------------------------------------------------------------

procedure TUIClient2WithAI.NextMove;
begin
  inherited;
  PostMessage(FStatusWindow.Handle,WM_USER+100,0,0);
end;

const
  E_TIMEOUT = SCORE_MIN - 1;

type
  TThinker = object
  private
    Board: TBoard;
    HadTimeout: boolean;
    _FreeOnBoard: integer;
    _Timeout: dword;
    _TSt: dword;

    StatMoves,
    StatCutoff,
    StatScored: int64;
    Log: procedure (Line: string) of object;
    procedure Init(Timeout: integer);
    function CheckTimeEnd: boolean;
    function Score(ABoard: TBoard; Perspective: TField): TScore;
    function NM_Move(Moving, Reacting: TField; ABoard: TBoard; Level: integer; Alpha, Beta: TScore;
                   out BestF,BestT: TFieldCoord): TScore;
    function FindMove(out BestF,BestT: TFieldCoord): TScore;
  end;

{ TThinker }

procedure TThinker.Init(Timeout: integer);
var r: TRowIndex;
    c: TColIndex;
begin
  _Timeout:= Timeout;
  _FreeOnBoard:= 0;
  for r:= low(r) to high(r) do
    for c:= low(c) to high(c) do
      if Board[c,r]<>Blocked then
        inc(_FreeOnBoard);
end;

function TThinker.FindMove(out BestF, BestT: TFieldCoord): TScore;
var ld: integer;
    bf,bt: TFieldCoord;
    sc: TScore;
begin
  Result:= SCORE_MIN;
  ld:= 2;
  _TSt:= GetTickCount;
  repeat
    inc(ld);
    HadTimeout:= false;
    StatMoves := 0;
    StatCutoff:= 0;
    StatScored:= 0;
    sc:= NM_Move(ThisPlayer, OtherPlayer, Board, ld, SCORE_MIN, SCORE_MAX, bf, bt);
    if not HadTimeout then begin
      Log(Format('  L:%d M:%d C:%d S:%d %d ms',[ld, StatMoves, StatCutoff, StatScored, GetTickCount - _TSt]));
      Log(Format('    Best: %s %s - %d',[bf,bt,sc]));
      Result:= sc;
      BestF:= bf;
      BestT:= bt;
    end else begin
      Log(Format('  L:%d  Timed out', [ld]));
      break;
    end;
  until CheckTimeEnd;
  Log(Format(' -> %d (%s %s) @ %d, %dms',[Result, BestF, BestT, ld, GetTickCount - _TSt]));
end;

function TThinker.CheckTimeEnd: boolean;
begin
  Result:= (GetTickCount > _TSt + _Timeout);
end;

function TThinker.NM_Move(Moving, Reacting: TField; ABoard: TBoard; Level: integer; Alpha, Beta: TScore; out BestF, BestT: TFieldCoord): TScore;
var r: TRowIndex;
    c: TColIndex;
    zug, z: integer;
    zugliste: array[0..200] of packed record
        einzel: boolean;
        FR: TRowIndex; FC: TColIndex;
        TR: TRowIndex; TC: TColIndex;
      end;
    procedure ZugAdd(ac: TColIndex; ar: TRowIndex);
    begin
                                   // inlined BoardValidCoords
      if (ABoard[ac,ar]=Empty) and ((ar in [low(ar)..high(ar)]) and (ac in [low(ac)..high(ac)])) then begin
        zugliste[zug].FC:= c;
        zugliste[zug].FR:= r;
        zugliste[zug].TC:= ac;
        zugliste[zug].TR:= ar;
        inc(zug);
        inc(StatMoves);
      end;
    end;

    procedure ZugEinzelAdd(ac: TColIndex; ar: TRowIndex);
    var k:integer;
    begin
      for k:= 0 to zug-1 do
        if (zugliste[k].einzel) and (zugliste[k].TC = ac) and (zugliste[k].TR = ar) then
          exit;
      //sonst
      zugliste[zug].einzel:= true;
      ZugAdd(ac,ar);
    end;

    function TryMove(fc: TColIndex; fr: TRowIndex; tc: TColIndex;
      tr: TRowIndex): boolean;
    var after: TBoard;
        df,dt: TFieldCoord;
        S: TScore;
    begin
      Result:= false;
      after:= ABoard;
      BoardMapMove(after,ColRowToFieldCoord(fc,fr),ColRowToFieldCoord(tc,tr));

      S:= -NM_Move(Reacting, Moving, after, Level - 1, -beta, -alpha, df,dt);

      if S > alpha then begin
        alpha:= S;
        BestF:= ColRowToFieldCoord(fc,fr);
        BestT:= ColRowToFieldCoord(tc,tr);
      end;
      if alpha >= beta then begin
        Result:= true;
        inc(StatCutoff);
      end;
    end;

begin
  Result:= E_TIMEOUT;
  if Level=0 then begin
    Result:= Score(ABoard, Moving);
    exit;
  end;

  if (Level>=6) and CheckTimeEnd then begin
    HadTimeout:= true;
    exit;
  end;

  ZeroMemory(@zugliste, Sizeof(Zugliste));

  zug:= 0;
// Einzelzüge
  for r:= low(R) to high(r) do
    for c:= low(c) to high(c) do
      if ABoard[c,r]=Moving then begin
        ZugEinzelAdd(pred(c),r-1);
        ZugEinzelAdd(pred(c),r);
        ZugEinzelAdd(pred(c),r+1);
        ZugEinzelAdd(succ(c),r-1);
        ZugEinzelAdd(succ(c),r);
        ZugEinzelAdd(succ(c),r+1);
        ZugEinzelAdd(c,r-1);
        ZugEinzelAdd(c,r+1);
      end;

// Doppelzüge
  for r:= low(R) to high(r) do
    for c:= low(c) to high(c) do
      if ABoard[c,r]=Moving then begin
        ZugAdd(pred(pred(c)),r-2);
        ZugAdd(pred(pred(c)),r);
        ZugAdd(pred(pred(c)),r+2);
        ZugAdd(succ(succ(c)),r-2);
        ZugAdd(succ(succ(c)),r);
        ZugAdd(succ(succ(c)),r+2);
        ZugAdd(c,r-2);
        ZugAdd(c,r+2);
      end;


  for z:= 0 to zug-1 do
    if zugliste[z].FR>0 then begin
      if TryMove(zugliste[z].FC,zugliste[z].FR,
                 zugliste[z].TC,zugliste[z].TR) then begin
        Result:= alpha;
        exit;
      end;
      if HadTimeout then
        exit;
    end else
      break;

  if Alpha=SCORE_MIN then           // wir konnten keinen zug machen
//      Result:= SCORE_MIN+Random(10)   // "leap of faith"
    Result:= Score(ABoard, Moving)  // bewerten, sollte ziemlich schlecht sein
  else
    Result:= Alpha;
end;

function TThinker.Score(ABoard: TBoard; Perspective: TField): TScore;
var r: TRowIndex;
    c: TColIndex;
    th,ot: integer;
const
  w1 = 20*100;
  w2 = 1000;
  w3 =  900;
begin
  th:= 0;
  ot:= 0;
  for r:= low(r) to high(r) do
    for c:= low(c) to high(c) do begin
      if ABoard[c,r]=Perspective then
        inc(th)
      else if ABoard[c,r] in [ThisPlayer,OtherPlayer] then      // a clever way to say "player, but not $perspective"
        inc(ot);
    end;
  Result:= Round((th / _FreeOnBoard)*w2) - Round((ot / _FreeOnBoard)*w3);
  inc(StatScored);
end;

//------------

function TUIClient2WithAI.AIGetMove(out FF, FT: TFieldCoord): TScore;
var turk: TThinker;
begin
  turk.Board:= Board;
  turk.Init(ThinkTime);
  TMethod(turk.Log).Code:= Addr(TStrings.Add);
  TMethod(turk.Log).Data:= FStatusWindow.meLog.Lines;

  Result:= turk.FindMove(FF,FT);
end;

procedure TGameWindow.Magic;
var f,t: TFieldCoord;
begin
  TUIClient2WithAI(Gm).AIGetMove(f,t);
  edMvFrom.Text:= f;
  edMvTo.Text:= t;
  Button1.Click;
end;

{ TUIClientWithAI }

class function TUIClientWithAI.ClientName: String;
begin
  Result:= 'MartokUIClient';
end;


end.
