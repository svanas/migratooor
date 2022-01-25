unit progress;

interface

uses
  // Delphi
  System.Classes,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Forms,
  FMX.StdCtrls,
  FMX.Types;

type
  TfrmProgress = class(TForm)
    btnCancel: TButton;
    indicator: TAniIndicator;
    lblMessage: TLabel;
    procedure btnCancelClick(Sender: TObject);
  private
    FCancelled: Boolean;
    procedure DoShow; override;
    procedure DoHide; override;
  public
    property Cancelled: Boolean read FCancelled;
  end;

var
  frmProgress: TfrmProgress;

implementation

{$R *.fmx}

procedure TfrmProgress.btnCancelClick(Sender: TObject);
begin
  FCancelled := True;
end;

procedure TfrmProgress.DoShow;
begin
  FCancelled := False;
  indicator.Enabled := True;
  inherited DoShow;
end;

procedure TfrmProgress.DoHide;
begin
  inherited DoHide;
  indicator.Enabled := False;
end;

end.
