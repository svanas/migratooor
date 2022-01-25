program migratooor;

uses
  System.StartUpCopy,
  FMX.Forms,
  main in 'main.pas' {frmMain},
  common in 'common.pas',
  asset in 'asset.pas',
  progress in 'progress.pas' {frmProgress};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
