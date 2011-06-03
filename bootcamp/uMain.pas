unit uMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Grids, uClientLogic, uProtocol, Math, Spin;

type
  TForm1 = class;
    
  TGame = class
  private
    Board: TBoard;
    FStatusWindow: TForm1;
    CurrentPlayer: TPlayerColor;
    FFWhite, FFBlack: integer;
  public
    constructor Create(Status: TForm1);
    procedure InitBoard;
    procedure LoadFactors(Black, White: integer);
    procedure NextMove;
    function Ended(out Winner: TPlayerColor): boolean;

    procedure DrawBoard;
  end;

  TForm1 = class(TForm)
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    lbPool: TListBox;
    Panel1: TPanel;
    btnInit: TButton;
    btnStartStop: TButton;
    Label1: TLabel;
    edInitValues: TEdit;
    tmrRun: TTimer;
    meLog: TMemo;
    sgBoard: TStringGrid;
    Panel2: TPanel;
    lbGameStat: TLabel;
    seThinkTime: TSpinEdit;
    sePoolSize: TSpinEdit;
    procedure btnInitClick(Sender: TObject);
    procedure btnStartStopClick(Sender: TObject);
    procedure tmrRunTimer(Sender: TObject);
    procedure sgBoardDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
  private
    { Private-Deklarationen }
    Game: TGame;
  public
    { Public-Deklarationen }
  end;

var
  Form1: TForm1;

implementation

uses DUStrings;

{$R *.dfm}

procedure TForm1.btnInitClick(Sender: TObject);
begin
  Randomize;  
  if tmrRun.Enabled then
    btnStartStop.Click;
  lbPool.Items.Clear;
  lbPool.Items.Add(edInitValues.Text);
  FreeAndNil(Game);
end;

procedure TForm1.btnStartStopClick(Sender: TObject);
begin
  tmrRun.Enabled:= not tmrRun.Enabled;
  if tmrRun.Enabled then
    btnStartStop.Caption:= 'Stop'
  else
    btnStartStop.Caption:= 'Start';
end;

procedure TForm1.tmrRunTimer(Sender: TObject);
var i,a,b:integer;
    winner: TPlayerColor;
    ilos,iwin: Integer;
  function Mutate(S:string): string;
  var pr: TStringArray;
      j,v: integer;
  begin
    pr:= SplitString(s,' ');
    j:= Random(Length(pr));
    v:= StrToInt(pr[j]) div 7;
    pr[j]:= IntToStr(StrToInt(pr[j])+random(v*2)-v);
    Result:= ConcatString(pr, ' ');
  end;

begin
  if Assigned(Game) then begin
    //Zug machen
    Game.NextMove;
    Game.DrawBoard;
    //wars das?
    if Game.Ended(Winner) then begin
      if Winner=Black then begin
        iwin:= Game.FFBlack;
        ilos:= Game.FFWhite;
      end else begin
        ilos:= Game.FFBlack;
        iwin:= Game.FFWhite;
      end;
      meLog.Lines.Add(Format('Spiel beendet. Sieger: %d',[iwin]));
      meLog.Lines.Add(Format('   %s',[lbPool.Items[iwin]]));

      // verlierer bestrafen
      if ilos<lbPool.Items.Count-1 then
        lbPool.Items.Exchange(ilos, ilos+1)
      else
        lbPool.Items.Delete(ilos);

      //gewinner belohnen
      if iwin>0 then
        lbPool.Items.Exchange(iwin, iwin-1);

      FreeAndNil(Game);

      // schlechte löschen
      i:= sePoolSize.Value-2-Random(sePoolSize.Value div 3);
      while lbPool.Items.Count>i do
        lbPool.Items.Delete(lbPool.Items.Count-1);
    end;
  end;

  // neues spiel starten?
  if not Assigned(Game) then begin
    // neue clonen
    while lbPool.Items.Count < sePoolSize.Value do
      lbPool.Items.Add(Mutate(lbPool.Items[Random(lbPool.Items.Count)]));

    Game:= TGame.Create(Self);
    Game.InitBoard;
    a:= random(lbPool.Items.Count div 2);   // someone from the top half
    b:= random(lbPool.Items.Count);         // against anyone else
    if random < 0.3 then begin              // a nicht immer anfangen lassen
      i:= a;
      a:= b;
      b:= i;
    end;
    meLog.Lines.Add('');
    meLog.Lines.Add('');
    meLog.Lines.Add(Format('Spiel geladen: %d vs %d',[a,b]));
    meLog.Lines.Add(Format('%s  vs  %s',[lbPool.Items[a],lbPool.Items[b]]));
    Game.LoadFactors(a, b);
    Game.DrawBoard;
  end;
end;

{ TGame }

constructor TGame.Create(Status: TForm1);
begin
  FStatusWindow:= Status;
end;

procedure TGame.DrawBoard;
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

function TGame.Ended(out Winner: TPlayerColor): boolean;
var sc: array[TField] of Integer;
    r: TRowIndex;
    c: TColIndex;
begin
  ZeroMemory(@sc, SizeOf(sc));
  for r:= low(r) to High(r) do
    for c:= low(c) to High(c) do
      inc(sc[Board[c,r]]);
  Result:= sc[Empty]=0;
  if sc[ThisPlayer]>sc[OtherPlayer] then
    Winner:= CurrentPlayer
  else begin
    if CurrentPlayer=White then
      Winner:= Black
    else
      Winner:= White;
  end;
end;

procedure TGame.InitBoard;
begin
  ZeroMemory(@Board, SizeOf(Board));
  Board['c',3]:= Blocked;
  Board['g',3]:= Blocked;
  Board['c',7]:= Blocked;
  Board['g',7]:= Blocked;

  BoardMapInit(Board, ThisPlayer, OtherPlayer);
end;

procedure TGame.LoadFactors(Black, White: integer);
begin
  FFWhite:= White;
  FFBlack:= Black;
  CurrentPlayer:= uProtocol.Black;
end;

procedure TGame.NextMove;
var Brain: TThinker;
    prm: TStringArray;
    FF, FT: TFieldCoord;
    r: TRowIndex;
    c: TColIndex;
    othermove: Boolean;
begin
  Brain.Board:= Board;
  Brain.Init(FStatusWindow.seThinkTime.Value);
  if CurrentPlayer=Black then
    prm:= SplitString(FStatusWindow.lbPool.Items[FFBlack],' ')
  else
    prm:= SplitString(FStatusWindow.lbPool.Items[FFWhite],' ');

  Brain.ScoreFactors[1]:= StrToInt(prm[0]);
  Brain.ScoreFactors[2]:= StrToInt(prm[1]);
  TMethod(Brain.Log).Code:= Addr(TStrings.Add);
  TMethod(Brain.Log).Data:= FStatusWindow.meLog.Lines;

  Brain.FindMove(FF,FT);
  BoardMapMove(Board, FF, FT);
  // wenn der andere nicht ziehen kann, nichts tun.

  othermove:= false;
  for r:= low(r) to High(r) do begin
    for c:= low(c) to High(c) do
      if Board[c,r]=OtherPlayer then begin
        if (BoardValidCoords(pred(c),r-1) and (Board[pred(c),r-1]=Empty)) or
           (BoardValidCoords(pred(c),r  ) and (Board[pred(c),r  ]=Empty)) or
           (BoardValidCoords(pred(c),r+1) and (Board[pred(c),r+1]=Empty)) or
           (BoardValidCoords(succ(c),r-1) and (Board[succ(c),r-1]=Empty)) or
           (BoardValidCoords(succ(c),r  ) and (Board[succ(c),r  ]=Empty)) or
           (BoardValidCoords(succ(c),r+1) and (Board[succ(c),r+1]=Empty)) or
           (BoardValidCoords(c,r-1      ) and (Board[c,r-1      ]=Empty)) or
           (BoardValidCoords(c,r+1      ) and (Board[c,r+1      ]=Empty)) or
           (BoardValidCoords(pred(pred(c)),r-2) and (Board[pred(pred(c)),r-2]=Empty)) or
           (BoardValidCoords(pred(pred(c)),r  ) and (Board[pred(pred(c)),r  ]=Empty)) or
           (BoardValidCoords(pred(pred(c)),r+2) and (Board[pred(pred(c)),r+2]=Empty)) or
           (BoardValidCoords(succ(succ(c)),r-2) and (Board[succ(succ(c)),r-2]=Empty)) or
           (BoardValidCoords(succ(succ(c)),r  ) and (Board[succ(succ(c)),r  ]=Empty)) or
           (BoardValidCoords(succ(succ(c)),r+2) and (Board[succ(succ(c)),r+2]=Empty)) or
           (BoardValidCoords(c,r-2) and (Board[c,r-2]=Empty)) or
           (BoardValidCoords(c,r+2) and (Board[c,r+2]=Empty)) then begin
          othermove:= true;
          Break;
        end;
      end;
    if othermove then
      break;  
  end;

  if othermove then begin
    // Brett drehen
    for r:= low(r) to High(r) do
      for c:= low(c) to High(c) do begin
        if Board[c,r]=ThisPlayer then Board[c,r]:=OtherPlayer else
        if Board[c,r]=OtherPlayer then Board[c,r]:=ThisPlayer;
      end;
    if CurrentPlayer=Black then
      CurrentPlayer:= White
    else
      CurrentPlayer:= Black;
  end
   else
     FStatusWindow.meLog.Lines.Add('Gegner muss passen');
end;

procedure TForm1.sgBoardDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var s: string;
    f: TFieldCoord;
    ThisCol, OtherCol: TColor;
begin
  sgBoard.Canvas.Brush.Color:= clWindow;
  sgBoard.Canvas.FillRect(Rect);
  InflateRect(Rect,-2,-2);
  s:= sgBoard.Cells[ACol,ARow];
  if s='' then s:= '0';
  if not Assigned(Game) then exit;
  if Game.CurrentPlayer = Black then begin
    ThisCol:= clBlack;
    OtherCol:= clSilver;
  end else begin
    ThisCol:= clSilver;
    OtherCol:= clBlack;
  end;
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

end.
