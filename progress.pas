unit progress;

interface

uses
  // Delphi
  System.Classes,
  System.UITypes,
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
  protected
    procedure DoShow; override;
    procedure DoHide; override;
  public
    function Prompt(const msg: string): TModalResult;
    procedure Step(const msg: string; idx, cnt: Integer);
    property Cancelled: Boolean read FCancelled;
  end;

function Get(aOwner: TForm): TfrmProgress;

implementation

{$R *.fmx}

uses
  // Delphi
  System.SysUtils;

var
  frmProgress: TfrmProgress = nil;

function Get(aOwner: TForm): TfrmProgress;
begin
  if not Assigned(frmProgress) then
    frmProgress := TfrmProgress.Create(aOwner);
  Result := frmProgress;
end;

procedure TfrmProgress.btnCancelClick(Sender: TObject);
begin
  FCancelled := True;
end;

procedure TfrmProgress.DoShow;
begin
  indicator.Enabled := True;
  inherited DoShow;
end;

procedure TfrmProgress.DoHide;
begin
  FCancelled := False;
  inherited DoHide;
  indicator.Enabled := False;
end;

function TfrmProgress.Prompt(const msg: string): TModalResult;
begin
  lblMessage.Text := msg;
  Result := Self.ShowModal;
end;

procedure TfrmProgress.Step(const msg: string; idx, cnt: Integer);
begin
  lblMessage.Text := Format(msg, [idx, cnt]);
end;

end.
