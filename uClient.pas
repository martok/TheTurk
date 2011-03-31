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
  TUIClient = class(TNetGame)
  private
    FStatusWindow: TGameWindow;
    procedure DrawBoard;
  public
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
    if Gm.Move(edMvFrom.Text,edMvTo.Text) then
      Gm.NextMove
    else
      pnMakeMove.Visible:= false;
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

function TUIClient2WithAI.AIGetMove(out FF, FT: TFieldCoord): TScore;
const
  LEVEL_DEPTH=4;
  
  function NM_Move(Moving, Reacting: TField; ABoard: TBoard; Level: integer; Alpha, Beta: TScore;
                   out BestF,BestT: TFieldCoord): TScore;
  var
    FreeOnBoard: integer;
    function Score(ABoard: TBoard; Perspective: TField): TScore;
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
      Result:= Round((th / FreeOnBoard)*w2) - Round((ot / FreeOnBoard)*w3);
    end;


    function TryMove(fc: TColIndex; fr: TRowIndex; tc: TColIndex; tr: TRowIndex): boolean;
    var after: TBoard;
        df,dt: TFieldCoord;
        S: TScore;
    begin
      Result:= false;
      if (BoardValidCoords(tc,tr)) and (ABoard[tc,tr]=Empty) then begin
        after:= ABoard;
        BoardMapMove(after,ColRowToFieldCoord(fc,fr),ColRowToFieldCoord(tc,tr),Moving);

        S:= -NM_Move(Reacting, Moving, after, Level - 1, -beta, -alpha, df,dt);

        if S > alpha then begin
          alpha:= S;
          BestF:= ColRowToFieldCoord(fc,fr);
          BestT:= ColRowToFieldCoord(tc,tr);
        end;
        if alpha >= beta then 
          Result:= true;
      end;
    end;

  var r: TRowIndex;
      c: TColIndex;
  begin
    FreeOnBoard:= 0;
    for r:= low(r) to high(r) do
      for c:= low(c) to high(c) do
        if ABoard[c,r]<>Blocked then
          inc(FreeOnBoard);

    if Level=0 then begin
      Result:= Score(ABoard, Moving);
      exit;
    end;

    for r:= low(R) to high(r) do
      for c:= low(c) to high(c) do
        if ABoard[c,r]=Moving then begin
          if TryMove(c,r,pred(c),r-1) or
            TryMove(c,r,pred(c),r) or
            TryMove(c,r,pred(c),r+1) or
            TryMove(c,r,succ(c),r-1) or
            TryMove(c,r,succ(c),r) or
            TryMove(c,r,succ(c),r+1) or
            TryMove(c,r,c,r-1) or
            TryMove(c,r,c,r+1) or

            TryMove(c,r,pred(pred(c)),r-2) or
            TryMove(c,r,pred(pred(c)),r) or
            TryMove(c,r,pred(pred(c)),r+2) or
            TryMove(c,r,succ(succ(c)),r-2) or
            TryMove(c,r,succ(succ(c)),r) or
            TryMove(c,r,succ(succ(c)),r+2) or
            TryMove(c,r,c,r-2) or
            TryMove(c,r,c,r+2) then begin
            Result:= alpha;
            exit;
          end;
        end;
    if Alpha=SCORE_MIN then           // wir konnten keinen zug machen
//      Result:= SCORE_MIN+Random(10)   // "leap of faith"
      Result:= Score(ABoard, Moving)  // bewerten, sollte ziemlich schlecht sein
    else
      Result:= Alpha;
  end;

begin
  Result:= NM_Move(ThisPlayer, OtherPlayer, Board, LEVEL_DEPTH, SCORE_MIN, SCORE_MAX, ff, ft);
  FStatusWindow.meLog.Lines.Add(Format(' -> %d',[Result]));
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
