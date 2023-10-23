program migratooor;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Types,
  main in 'main.pas' {frmMain},
  asset in 'asset.pas',
  progress in 'progress.pas' {frmProgress};

{$R *.res}

begin
  GlobalUseMetal := True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
