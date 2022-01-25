unit main;

interface

uses
  // Delphi
  System.Classes,
  System.Rtti,
  System.SysUtils,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.Forms,
  FMX.Grid,
  FMX.Grid.Style,
  FMX.ListBox,
  FMX.ScrollBox,
  FMX.StdCtrls,
  FMX.Types,
  // web3
  web3,
  web3.eth.types,
  // Project
  asset;

type
  TfrmMain = class(TForm)
    lblAddress: TLabel;
    edtAddress: TEdit;
    cboChain: TComboBox;
    btnScan: TButton;
    Grid: TGrid;
    colCheck: TCheckColumn;
    colImage: TImageColumn;
    colName: TStringColumn;
    colBalance: TFloatColumn;
    Header: TPanel;
    chkSelectAll: TCheckBox;
    procedure btnScanClick(Sender: TObject);
    procedure chkSelectAllChange(Sender: TObject);
    procedure GridGetValue(Sender: TObject; const ACol, ARow: Integer;
      var Value: TValue);
    procedure GridSetValue(Sender: TObject; const ACol, ARow: Integer;
      const Value: TValue);
  private
    FAssets: TAssets;
    procedure Address(callback: TAsyncAddress);
    class function Cancelled: Boolean;
    function Chain: TChain;
    procedure Clear;
    function Client: IWeb3;
    class function Ethereum: IWeb3;
    procedure InitUI;
    class procedure Synchronize(P: TThreadProcedure);
    procedure UpdateUI;
  public
    constructor Create(aOwner: TComponent); override;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  // Delphi
  System.Net.HttpClient,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.eth,
  web3.eth.infura,
  web3.eth.tokenlists,
  web3.http,
  // Project
  common,
  progress;

//------------------------------- event handlers -------------------------------

procedure TfrmMain.btnScanClick(Sender: TObject);
begin
  UpdateUI;
end;

procedure TfrmMain.chkSelectAllChange(Sender: TObject);
begin
  for var idx := 0 to Length(FAssets) - 1 do
  begin
    FAssets[idx].Check(chkSelectAll.IsChecked);
    colCheck.UpdateCell(idx);
  end;
end;

procedure TfrmMain.GridGetValue(Sender: TObject; const ACol, ARow: Integer;
  var Value: TValue);
begin
  case ACol of
    0: Value := FAssets[ARow].Checked;
    1: Value := FAssets[ARow].Bitmap;
    2: Value := FAssets[ARow].Token.Name;
    3: Value := FAssets[ARow].Balance;
  end;
end;

procedure TfrmMain.GridSetValue(Sender: TObject; const ACol, ARow: Integer;
  const Value: TValue);
begin
  if ACol = 0 then FAssets[ARow].Check(Value.AsBoolean);
end;

//---------------------------------- public -----------------------------------

constructor TfrmMain.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  InitUI;
end;

//---------------------------------- private -----------------------------------

procedure TfrmMain.Address(callback: TAsyncAddress);
begin
  if edtAddress.Text.Length = 0 then
    callback(EMPTY_ADDRESS, nil)
  else
    TAddress.New(Ethereum, edtAddress.Text, callback);
end;

class function TfrmMain.Cancelled: Boolean;
begin
  Result := Assigned(frmProgress) and frmProgress.Cancelled;
  if Result then
    if frmProgress.Visible then frmProgress.Close;
end;

function TfrmMain.Chain: TChain;
begin
  Result := TChain(cboChain.Items.Objects[cboChain.ItemIndex]);
end;

procedure TfrmMain.Clear;
begin
  FAssets := [];
  Grid.RowCount := 0;
  chkSelectAll.IsChecked := True;
  Self.Invalidate;
end;

function TfrmMain.Client: IWeb3;
begin
  Result := TWeb3.Create(Chain, web3.eth.infura.endpoint(Chain, INFURA_PROJECT_ID));
end;

class function TfrmMain.Ethereum: IWeb3;
begin
  Result := TWeb3.Create(web3.Ethereum, web3.eth.infura.endpoint(web3.Ethereum, INFURA_PROJECT_ID));
end;

procedure TfrmMain.InitUI;
begin
  for var chain in CHAINS do
    cboChain.Items.AddObject(chain.Name, TObject(chain));
  cboChain.ItemIndex := 0;
  edtAddress.SetFocus;
end;

class procedure TfrmMain.Synchronize(P: TThreadProcedure);
begin
  if TThread.CurrentThread.ThreadID = MainThreadId then
    P
  else
    TThread.Synchronize(nil, procedure
    begin
      P
    end);
end;

procedure TfrmMain.UpdateUI;
begin
  Self.Clear;

  // step #1: resolve the ENS name
  Self.Address(procedure(owner: TAddress; err: IError)
  begin
    if Self.Cancelled then EXIT;

    if Assigned(err) then
    begin
      common.ShowError(err, Chain);
      EXIT;
    end;

    // step #2: get the tokens on this chain that Uniswap knows about
    web3.eth.tokenlists.tokens(Chain, procedure(tokens: TTokens; err: IError)
    begin
      if Self.Cancelled then EXIT;

      if Assigned(err) then
      begin
        common.ShowError(err, Chain);
        EXIT;
      end;

      if Assigned(frmProgress) then Self.Synchronize(procedure
      begin
        frmProgress.Count := Length(tokens);
      end);

      // step #3: get your balance for each token
      tokens.Enumerate(
        // foreach
        procedure(idx: Integer; next: TProc)
        begin
          if Assigned(frmProgress) then Self.Synchronize(procedure
          begin
            frmProgress.Step := idx;
          end);

          tokens[idx].Balance(Client, owner, procedure(balance: BigInteger; err: IError)
          begin
            if Self.Cancelled then EXIT;

            if Assigned(err) then
            begin
              next;
              EXIT;
            end;

            if balance.IsPositive then
            begin
              FAssets := FAssets + [asset.Create(tokens[idx], balance)];
              Self.Synchronize(procedure
              begin
                Grid.RowCount := Length(FAssets);
                Self.Invalidate;
              end);
            end;

            next;
          end);
        end,
        // done
        procedure
        begin
          // step #4: download and display the token icon
          Self.FAssets.Enumerate(
            // foreach
            procedure(idx: Integer; next: TProc)
            begin
              if FAssets[idx].Token.LogoURI.IsEmpty then
              begin
                next;
                EXIT;
              end;

              web3.http.get(FAssets[idx].Token.LogoURI.Replace('ipfs://', IPFS_GATEWAY), procedure(img: IHttpResponse; err: IError)
              begin
                if Self.Cancelled then EXIT;

                if Assigned(err) then
                begin
                  next;
                  EXIT;
                end;

                try
                  FAssets[idx].Bitmap.LoadFromStream(img.ContentStream);
                except end;

                Synchronize(procedure
                begin
                  colImage.UpdateCell(idx);
                end);

                next;
              end);
            end,
            // done
            procedure
            begin
              if Assigned(frmProgress) and frmProgress.Visible then frmProgress.Close;
            end
          );
        end
      );
    end);
  end);

  if not Assigned(frmProgress) then frmProgress := TfrmProgress.Create(Self);
  frmProgress.ShowModal;
end;

end.
