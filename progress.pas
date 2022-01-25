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
    FCount: Integer;
    procedure SetStep(Value: Integer);
  protected
    procedure DoShow; override;
    procedure DoHide; override;
  public
    property Cancelled: Boolean read FCancelled;
    property Step: Integer write SetStep;
    property Count: Integer write FCount;
  end;

var
  frmProgress: TfrmProgress;

implementation

{$R *.fmx}

uses
  // Delphi
  System.SysUtils;

procedure TfrmProgress.btnCancelClick(Sender: TObject);
begin
  FCancelled := True;
end;

procedure TfrmProgress.SetStep(Value: Integer);
begin
  lblMessage.Text := Format('Scanning for %d/%d tokens in your wallet. Please wait...', [Value, FCount]);
end;

procedure TfrmProgress.DoShow;
begin
  lblMessage.Text := 'Scanning for tokens in your wallet. Please wait...';
  indicator.Enabled := True;
  inherited DoShow;
end;

procedure TfrmProgress.DoHide;
begin
  FCancelled := False;
  inherited DoHide;
  indicator.Enabled := False;
end;

end.
