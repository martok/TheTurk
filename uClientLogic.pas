unit uClientLogic;

interface

uses Windows, SysUtils, Classes, uProtocol, uClient;

const
  E_TIMEOUT = SCORE_MIN - 1;

type
  TTimeoutThread = class(TThread)
  private
    FFlag: PBoolean;
    FTimeout: Cardinal;
  protected
    procedure Execute; override;
  public
    constructor Create(const Timeout: Cardinal; const TimeoutFlag: PBoolean); 
    procedure StartWaiting;
  end;

  TThinker = object
  private
    _FreeOnBoard: integer;
    _TSt: dword;
    _Timeout: dword;
  public
    Board: TBoard;
    HadTimeout: boolean;
    ScoreFactors: array[1..2] of Integer;

    StatMoves,
    StatCutoff,
    StatScored: int64;
    Log: procedure (Line: string) of object;
    procedure Init(Timeout: integer);
    function Score(ABoard: TBoard; Perspective: TField): TScore;
    function NM_Move(Moving, Reacting: TField; ABoard: TBoard; Level: integer; Alpha, Beta: TScore;
                   out BestF,BestT: TFieldCoord): TScore;
    function FindMove(out BestF,BestT: TFieldCoord): TScore;
  end;

implementation

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
    timer: TTimeoutThread;
begin
  Result:= SCORE_MIN;
  ld:= 2;
  _TSt:= GetTickCount;
  HadTimeout:= false;
  timer:= TTimeoutThread.Create(ThinkTime, @HadTimeout);
  try
    timer.StartWaiting;
    repeat
      inc(ld);
      StatMoves := 0;
      StatCutoff:= 0;
      StatScored:= 0;
      sc:= NM_Move(ThisPlayer, OtherPlayer, Board, ld, SCORE_MIN, SCORE_MAX, bf, bt);
      if not HadTimeout then begin
        Log(Format('  L:%d M:%d C:%d S:%d %d ms',[ld, StatMoves, StatCutoff, StatScored, GetTickCount - _TSt]));
        Log(Format('    Best: %s %s : %d',[bf,bt,sc]));
        Result:= sc;
        BestF:= bf;
        BestT:= bt;
      end else
        Log(Format('  L:%d  Timed out', [ld]));
    until HadTimeout;
  finally
    FreeAndNil(timer);
  end;
  Log(Format(' -> %d (%s %s) @ %d, %dms',[Result, BestF, BestT, ld, GetTickCount - _TSt]));
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
    // ac MUSS GüLTIG SEIN!
    begin
                                   // inlined BoardValidCoords
      if (ABoard[ac,ar]=Empty) and (ar in [low(ar)..high(ar)]) then begin
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

  if HadTimeout then
    exit;

  ZeroMemory(@zugliste, Sizeof(Zugliste));

  zug:= 0;
// Einzelzüge
  for r:= low(r) to high(r) do
    for c:= low(c) to high(c) do
      if ABoard[c,r]=Moving then begin
        if c>low(c) then begin
          ZugEinzelAdd(pred(c),r-1);
          ZugEinzelAdd(pred(c),r);
          ZugEinzelAdd(pred(c),r+1);
        end;
        if c<high(c) then begin
          ZugEinzelAdd(succ(c),r-1);
          ZugEinzelAdd(succ(c),r);
          ZugEinzelAdd(succ(c),r+1);
        end;
        ZugEinzelAdd(c,r-1);
        ZugEinzelAdd(c,r+1);
      end;

// Doppelzüge
  for r:= low(R) to high(r) do
    for c:= low(c) to high(c) do
      if ABoard[c,r]=Moving then begin
        if c>Succ(low(c)) then begin
          ZugAdd(pred(pred(c)),r-2);
          ZugAdd(pred(pred(c)),r);
          ZugAdd(pred(pred(c)),r+2);
        end;
        if c<Pred(high(c)) then begin
          ZugAdd(succ(succ(c)),r-2);
          ZugAdd(succ(succ(c)),r);
          ZugAdd(succ(succ(c)),r+2);
        end;
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
{
  Alright, think this through.

  #  th > ot
  #  th > total/2

}
var r: TRowIndex;
    c: TColIndex;
    th,ot: integer;
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
  Result:= Round(ScoreFactors[1] * (th-ot)) +
           Round(ScoreFactors[2] * sqr(th / (_FreeOnBoard / 2)));

  inc(StatScored);
end;

//------------

{ TTimeoutThread }

constructor TTimeoutThread.Create(const Timeout: Cardinal;
  const TimeoutFlag: PBoolean);
begin
  inherited Create(true);
  FFlag:= TimeoutFlag;
  FTimeout:= Timeout;
end;

procedure TTimeoutThread.Execute;
begin
  Sleep(FTimeout);
  FFlag^:= true;
end;

procedure TTimeoutThread.StartWaiting;
begin
  FFlag^:= false;
  Resume;
end;

end.
 