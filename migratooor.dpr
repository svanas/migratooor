program migratooor;

uses
  System.StartUpCopy,
  FMX.Forms,
  main in 'main.pas' {frmMain},
  common in 'common.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
