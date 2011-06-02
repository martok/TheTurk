program BKI;

uses
  FastMM4,
  Forms,
  uGUI in 'uGUI.pas' {BKIMain},
  uProtocol in 'uProtocol.pas',
  uClient in 'uClient.pas' {GameWindow},
  uClientLogic in 'uClientLogic.pas';

{$R *.res}

begin
  Randomize;
  Application.Initialize;
  Application.CreateForm(TBKIMain, BKIMain);
  Application.CreateForm(TGameWindow, GameWindow);
  Application.Run;
end.
