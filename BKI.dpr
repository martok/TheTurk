program BKI;

uses
  Forms,
  uGUI in 'uGUI.pas' {BKIMain},
  uProtocol in 'uProtocol.pas',
  uClient in 'uClient.pas' {GameWindow};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TBKIMain, BKIMain);
  Application.CreateForm(TGameWindow, GameWindow);
  Application.Run;
end.
