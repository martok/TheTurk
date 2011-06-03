program Bootcamp;

uses
  Forms,
  uMain in 'uMain.pas' {Form1},
  uClientLogic in '..\uClientLogic.pas',
  uProtocol in '..\uProtocol.pas',
  uClient in '..\uClient.pas' {GameWindow};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TGameWindow, GameWindow);
  Application.Run;
end.
