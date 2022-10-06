program migratooor;

uses
  System.StartUpCopy,
  FMX.Forms,
  main in 'main.pas' {frmMain},
  asset in 'asset.pas',
  common in 'common.pas',
  progress in 'progress.pas' {frmProgress};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
