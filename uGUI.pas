unit uGUI;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, uProtocol, ExtCtrls, Spin, uClient;

type
  TBKIMain = class(TForm)
    Panel1: TPanel;
    edHostURL: TEdit;
    Label1: TLabel;
    btnConnect: TButton;
    btnLeave: TButton;
    Bevel1: TBevel;
    Panel2: TPanel;
    Logger: TMemo;
    lbClientList: TListBox;
    tmrClock: TTimer;
    seClock: TSpinEdit;
    Label4: TLabel;
    Label5: TLabel;
    cbChooseClass: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure btnLeaveClick(Sender: TObject);
    procedure seClockChange(Sender: TObject);
    procedure tmrClockTimer(Sender: TObject);
    procedure lbClientListDblClick(Sender: TObject);
  private
    { Private-Deklarationen }
    Client: TNetGameProtocol;
  public
    { Public-Deklarationen }
  end;

var
  BKIMain: TBKIMain;

implementation

{$R *.dfm}

procedure TBKIMain.FormCreate(Sender: TObject);
begin
  btnConnect.Enabled:= true;
  cbChooseClass.Enabled:= true;
  btnLeave.Enabled:= false;
  Client:= nil;
  cbChooseClass.Items.AddObject(TUIClient.ClassName       +'     '+TUIClient.ClientName, TObject(TUIClient));
  cbChooseClass.Items.AddObject(TUIClient2WithAI.ClassName+'     '+TUIClient2WithAI.ClientName, TObject(TUIClient2WithAI));
  cbChooseClass.Items.AddObject(TUIClientWithAI.ClassName +'     '+TUIClientWithAI.ClientName, TObject(TUIClientWithAI));
end;

procedure TBKIMain.btnConnectClick(Sender: TObject);
var c: TNetGameClass;
begin
  Client:= TNetGameProtocol.Create(edHostURL.Text);
  try
    tmrClock.Interval:= seClock.Value*1000;

    c:= TNetGameClass(cbChooseClass.Items.Objects[cbChooseClass.ItemIndex]);
    Logger.Lines.Add('Client erzeugt, baue Session auf ('+c.ClientName+')');
    Client.CreateSession(c);
    Logger.Lines.Add('Session erzeugt: '+Client.SessionId);
    tmrClockTimer(Self);

    btnConnect.Enabled:= false;
    cbChooseClass.Enabled:= false;
    btnLeave.Enabled:= true;
  except
    FreeAndNil(Client);
    raise;
  end;
end;

procedure TBKIMain.btnLeaveClick(Sender: TObject);
begin
  Client.EndSession;
  Logger.Lines.Add('Session beendet');
  FreeAndNil(Client);
  Logger.Lines.Add('Client freigegeben');
  btnConnect.Enabled:= true;
  cbChooseClass.Enabled:= true;
  btnLeave.Enabled:= false;
end;

procedure TBKIMain.seClockChange(Sender: TObject);
begin
  tmrClock.Interval:= seClock.Value*1000;
end;

procedure TBKIMain.tmrClockTimer(Sender: TObject);
var i:integer;
begin
  if Assigned(Client) then begin
    Logger.Lines.Add('Hole Client-Liste...');
    Client.GetClientList(lbClientList.Items);
    for i:= 0 to lbClientList.Items.Count-1 do
      lbClientList.Items[i]:= IntToStr(Integer(lbClientList.Items.Objects[i]))+'  '+lbClientList.Items[i];
    Logger.Lines.Add('Hole Actions...');
    Client.GetActions;
  end;
end;

procedure TBKIMain.lbClientListDblClick(Sender: TObject);
var c: string;
    psn: Integer;
begin
  if Assigned(Client) and (lbClientList.ItemIndex>=0) then begin
    c:= lbClientList.Items[lbClientList.ItemIndex];
    psn:= Integer(lbClientList.Items.Objects[lbClientList.ItemIndex]);
    if MessageDlg('Spiel gegen '+c+' starten?', mtConfirmation, [mbYes, mbNo], 0)=mrYes then
      Logger.Lines.Add('Spiel initiiert: '+IntToStr(Client.StartGame(psn).ID));
  end;
end;

end.
