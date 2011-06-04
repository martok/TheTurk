unit uClient;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, uProtocol, Grids, StdCtrls, ExtCtrls;

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

  TTurk = class(TUIClient)
  public
    class function ClientName: String; override;
    class function ClientSecret: String; override;
    procedure NextMove; override;

    function AIGetMove(out FF,FT: TFieldCoord): TScore;
  end;

var
  GameWindow: TGameWindow;

  ThinkTime: integer = 5000;

implementation

uses uClientLogic;


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

procedure TTurk.NextMove;
begin
  inherited;
  PostMessage(FStatusWindow.Handle,WM_USER+100,0,0);
end;

class function TTurk.ClientName: String;
begin
  Result:= 'TheTurk';
end;

class function TTurk.ClientSecret: String;
begin
  Result:= ClientSecret_TheTurk;
end;

function TTurk.AIGetMove(out FF, FT: TFieldCoord): TScore;
var Brain: TThinker;
begin
  Brain.Board:= Board;
  Brain.Init(ThinkTime);
(*
Bootcamp sagt:
24 38      baut geschlossene flächen, sichere inseln
 30 43

 33 28      konvertiert
Einzelwertung per DoppelDuell (Hin-Rückspiel). 24 38 hat alle 4 Spiele gewonnen
*)
  Brain.ScoreFactors[1]:= 24;
  Brain.ScoreFactors[2]:= 38;
  TMethod(Brain.Log).Code:= Addr(TStrings.Add);
  TMethod(Brain.Log).Data:= FStatusWindow.meLog.Lines;

  Result:= Brain.FindMove(FF,FT);
end;

procedure TGameWindow.Magic;
var f,t: TFieldCoord;
begin
  TTurk(Gm).AIGetMove(f,t);
  edMvFrom.Text:= f;
  edMvTo.Text:= t;
  Button1.Click;
end;

end.
