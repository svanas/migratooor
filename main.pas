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
    lblOwner: TLabel;
    edtOwner: TEdit;
    cboChain: TComboBox;
    btnScan: TButton;
    Grid: TGrid;
    colCheck: TCheckColumn;
    colImage: TImageColumn;
    colName: TStringColumn;
    colBalance: TFloatColumn;
    Header: TPanel;
    chkSelectAll: TCheckBox;
    edtRecipient: TEdit;
    lblRecipient: TLabel;
    btnMigrate: TButton;
    btnNew: TEditButton;
    chkUniswapPairs: TCheckBox;
    procedure cboChainChange(Sender: TObject);
    procedure btnMigrateClick(Sender: TObject);
    procedure btnNewClick(Sender: TObject);
    procedure btnScanClick(Sender: TObject);
    procedure chkSelectAllChange(Sender: TObject);
    procedure chkUniswapPairsChange(Sender: TObject);
    procedure GridGetValue(Sender: TObject; const ACol, ARow: Integer;
      var Value: TValue);
    procedure GridSetValue(Sender: TObject; const ACol, ARow: Integer;
      const Value: TValue);
  private
    FAssets: TAssets;
    FLocked: Integer;
    function Cancelled: Boolean;
    function Chain: TChain;
    procedure Clear;
    function Client: IWeb3;
    class function Ethereum: IWeb3;
    procedure Generate;
    procedure Init;
    procedure Lock;
    function Locked: Boolean;
    procedure Migrate;
    procedure Owner(callback: TAsyncAddress);
    procedure Recipient(callback: TAsyncAddress);
    procedure Scan(bUniswap: Boolean);
    class procedure Synchronize(P: TThreadProcedure);
    procedure Unlock;
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
  System.UITypes,
  // FireMonkey
  FMX.Dialogs,
  FMX.Platform,
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

{$I migratooor.api.key}

//------------------------------- event handlers -------------------------------

procedure TfrmMain.cboChainChange(Sender: TObject);
begin
  Self.Lock;
  try
    chkUniswapPairs.IsChecked := Chain = web3.Ethereum;
    chkUniswapPairs.Enabled   := Chain = web3.Ethereum;
  finally
    Self.Unlock;
  end;
end;

procedure TfrmMain.btnMigrateClick(Sender: TObject);
begin
  Self.Migrate;
end;

procedure TfrmMain.btnNewClick(Sender: TObject);
begin
  Self.Generate;
end;

procedure TfrmMain.btnScanClick(Sender: TObject);
begin
  Self.Scan((Chain = web3.Ethereum) and chkUniswapPairs.IsChecked);
end;

procedure TfrmMain.chkSelectAllChange(Sender: TObject);
begin
  for var idx := 0 to Length(FAssets) - 1 do
  begin
    FAssets[idx].Check(chkSelectAll.IsChecked);
    colCheck.UpdateCell(idx);
  end;
end;

procedure TfrmMain.chkUniswapPairsChange(Sender: TObject);
begin
  if not Self.Locked then
    Self.Scan((Chain = web3.Ethereum) and chkUniswapPairs.IsChecked);
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
  Init;
end;

//---------------------------------- private -----------------------------------

function TfrmMain.Cancelled: Boolean;
begin
  var P := progress.Get(Self);
  Result := Assigned(P) and P.Cancelled;
  if Result then
    if P.Visible then P.Close;
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
  btnMigrate.Enabled := False;
  Self.Invalidate;
end;

function TfrmMain.Client: IWeb3;
begin
  var aClient := TWeb3.Create(Chain, web3.eth.infura.endpoint(Chain, INFURA_PROJECT_ID));

  // do not approve each and every transaction individually
  aClient.OnSignatureRequest := procedure(
    from, &to   : TAddress;
    gasPrice    : TWei;
    estimatedGas: BigInteger;
    callback    : TSignatureRequestResult)
  begin
    callback(True, nil);
  end;

  Result := aClient;
end;

class function TfrmMain.Ethereum: IWeb3;
begin
  Result := TWeb3.Create(web3.Ethereum, web3.eth.infura.endpoint(web3.Ethereum, INFURA_PROJECT_ID));
end;

procedure TfrmMain.Generate;
begin
  var &private := TPrivateKey.Generate;
  &private.Address(procedure(&public: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      common.ShowError(err, Chain);
      EXIT;
    end;
    var svc: IFMXClipboardService;
    if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, svc) then
    begin
      svc.SetClipboard(string(&private));
      Self.Synchronize(procedure
      begin
        edtRecipient.Text := string(&public);
        MessageDlg(
          'A new wallet has been generated for you.' + #10#10 +
          'Your private key has been copied to the clipboard.' + #10#10 +
          'Please paste your private key in a safe place (for example: your password manager), then clear the clipboard.',
          TMsgDlgType.mtInformation, [TMsgDlgBtn.mbOK], 0);
      end);
    end;
  end);
end;

procedure TfrmMain.Init;
begin
  for var chain in CHAINS do
    cboChain.Items.AddObject(chain.Name, TObject(chain));
  cboChain.ItemIndex := 0;
  edtOwner.SetFocus;
end;

procedure TfrmMain.Lock;
begin
  Inc(FLocked);
end;

function TfrmMain.Locked: Boolean;
begin
  Result := FLocked > 0;
end;

procedure TfrmMain.Migrate;
begin
  var count := FAssets.Checked;
  if count = 0 then
  begin
    common.ShowError('Nothing to do.');
    EXIT;
  end;
  Self.Owner(procedure(aOwner: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      common.ShowError(err, web3.Ethereum);
      EXIT;
    end;
    aOwner.ToString(Ethereum, procedure(const sOwner: string; err: IError)
    begin
      if Assigned(err) then
      begin
        common.ShowError(err, web3.Ethereum);
        EXIT;
      end;
      Self.Recipient(procedure(aRecipient: TAddress; err: IError)
      begin
        if Assigned(err) then
        begin
          common.ShowError(err, web3.Ethereum);
          EXIT;
        end;
        aRecipient.ToString(Ethereum, procedure(const sRecipient: string; err: IError)
        begin
          if Assigned(err) then
          begin
            common.ShowError(err, web3.Ethereum);
            EXIT;
          end;
          var answer: Integer;
          Self.Synchronize(procedure
          begin
            answer := MessageDlg(
              Format('Are you sure you want to migrate %d tokens from %s to %s on the %s network?', [count, sOwner, sRecipient, Chain.Name]),
              TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0
            )
          end);
          if answer = mrYes then
          begin
            var &private := common.GetPrivateKey(aOwner);
            if &private <> '' then
            begin
              FAssets.Enumerate(
                // foreach
                procedure(idx: Integer; next: TProc)
                begin
                  if not FAssets[idx].Checked then
                  begin
                    next;
                    EXIT;
                  end;

                  Self.Synchronize(procedure
                  begin
                    progress.Get(Self).Step('Sending transaction %d of %d. Please wait...', idx, count);
                  end);

                  FAssets[idx].Transfer(Client, &private, aRecipient, procedure(hash: TTxHash; err: IError)
                  begin
                    if Self.Cancelled then EXIT;
                    next;
                  end);
                end,
                // done
                procedure
                begin
                  progress.Get(Self).Close;
                end
              );
              progress.Get(Self).Prompt(Format('Sending %d transactions. Please wait...', [count]));
            end;
          end;
        end, True);
      end);
    end, True);
  end);
end;

procedure TfrmMain.Owner(callback: TAsyncAddress);
begin
  if edtOwner.Text.Length = 0 then
    callback(EMPTY_ADDRESS, nil)
  else
    TAddress.New(Ethereum, edtOwner.Text, callback);
end;

procedure TfrmMain.Recipient(callback: TAsyncAddress);
begin
  TAddress.New(Ethereum, edtRecipient.Text, procedure(recipient: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(EMPTY_ADDRESS, err);
      EXIT;
    end;
    if recipient.IsZero then
    begin
      callback(EMPTY_ADDRESS, TError.Create('Recipient address is invalid.'));
      EXIT;
    end;
    callback(recipient, nil);
  end);
end;

// includes 30k Uniswap v2 LP tokens if bUniswap is true, otherwise no LP tokens
procedure TfrmMain.Scan(bUniswap: Boolean);
begin
  Self.Clear;

  var enumerate := procedure(owner: TAddress; tokens: TTokens)
  begin
    // step #4: get your balance for each token
    tokens.Enumerate(
      // foreach
      procedure(idx: Integer; next: TProc)
      begin
        Self.Synchronize(procedure
        begin
          progress.Get(Self).Step('Scanning for %d/%d tokens in your wallet. Please wait...', idx, Length(tokens));
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
              btnMigrate.Enabled := True;
              Self.Invalidate;
            end);
          end;

          next;
        end);
      end,
      // done
      procedure
      begin
        // step #5: download and display the token icon
        FAssets.Enumerate(
          // foreach
          procedure(idx: Integer; next: TProc)
          begin
            if FAssets[idx].Token.LogoURI.IsEmpty then
            begin
              next;
              EXIT;
            end;

            web3.http.get(FAssets[idx].Token.LogoURI.Replace('ipfs://', 'https://ipfs.io/ipfs/'), procedure(img: IHttpResponse; err: IError)
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
            progress.Get(Self).Close;
          end
        );
      end
    );
  end;

  // step #1: resolve the owner ENS name
  Self.Owner(procedure(owner: TAddress; err: IError)
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

      // step #3: include 30k Uniswap v2 LP tokens (optional)
      if bUniswap then
      begin
        web3.eth.tokenlists.tokens('https://raw.githubusercontent.com/jab416171/uniswap-pairtokens/master/uniswap_pair_tokens.json', procedure(uniswap: TTokens; err: IError)
        begin
          if Self.Cancelled then EXIT;

          if Assigned(err) then
          begin
            common.ShowError(err, Chain);
            EXIT;
          end;

          enumerate(owner, tokens + uniswap);
        end);
        EXIT;
      end;

      enumerate(owner, tokens);
    end);
  end);

  progress.Get(Self).Prompt('Scanning for tokens in your wallet. Please wait...');
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

procedure TfrmMain.Unlock;
begin
  if FLocked > 0 then Dec(FLocked);
end;

end.
