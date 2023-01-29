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
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.types,
  // Project
  asset;

type
  TSetting = (
    UniswapPairs, // scan for 30k Uniswap v2 LP tokens if included, otherwise no LP tokens
    NFTs // scan for (erc-721 and erc-1155) NFTs using the OpenSea API, otherwise no NFTs.
  );
  TSettings = set of TSetting;

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
    chkScanForUniswapPairs: TCheckBox;
    chkScanForNFTs: TCheckBox;
    chkScanForERC20s: TCheckBox;
    procedure btnMigrateClick(Sender: TObject);
    procedure btnNewClick(Sender: TObject);
    procedure btnScanClick(Sender: TObject);
    procedure cboChainChange(Sender: TObject);
    procedure chkScanForChange(Sender: TObject);
    procedure chkSelectAllChange(Sender: TObject);
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
    function GetClient: IResult<IWeb3>;
    procedure Count(aSettings: TSettings; callback: TProc<BigInteger, IError>);
    class function Ethereum: IWeb3;
    procedure Generate;
    procedure Init;
    procedure Lock;
    function Locked: Boolean;
    procedure Migrate;
    procedure Owner(callback: TProc<TAddress, IError>);
    procedure Recipient(callback: TProc<TAddress, IError>);
    procedure Scan(aSettings: TSettings);
    function Settings: TSettings;
    class procedure Queue(P: TThreadProcedure);
    class procedure Synchronize(P: TThreadProcedure);
    procedure Unlock;
    procedure Update;
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
  FMX.BehaviorManager,
  FMX.Dialogs,
  FMX.Platform,
  // web3
  web3.error,
  web3.eth,
  web3.eth.infura,
  web3.eth.opensea,
  web3.eth.tokenlists,
  web3.http,
  // Project
  progress;

{$I migratooor.api.key}

const
  UNISWAP_PAIR_TOKENS = 'https://raw.githubusercontent.com/jab416171/uniswap-pairtokens/master/uniswap_pair_tokens.json';

//------------------------------- event handlers -------------------------------

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
  Self.Scan(Self.Settings);
end;

procedure TfrmMain.cboChainChange(Sender: TObject);
begin
  Self.Lock;
  try
    chkScanForERC20s.Text := 'Scan for (calculating...) ERC-20 tokens';
    web3.eth.tokenlists.count(Chain, procedure(cnt: BigInteger; err: IError)
    begin
      Self.Queue(procedure
      begin
        chkScanForERC20s.Text := Format('Scan for %s known ERC-20 tokens', [cnt.ToString]);
      end);
    end);

    chkScanForNFTs.Enabled := (Chain = web3.Ethereum) or (Chain = web3.Goerli);
    chkScanForNFTs.IsChecked := chkScanForNFTs.Enabled;

    chkScanForUniswapPairs.Enabled := Chain = web3.Ethereum;
    if not chkScanForUniswapPairs.Enabled then
      chkScanForUniswapPairs.IsChecked := False;
  finally
    Self.Unlock;
  end;
end;

procedure TfrmMain.chkScanForChange(Sender: TObject);
begin
  if not Self.Locked then Self.Scan(Self.Settings);
end;

procedure TfrmMain.chkSelectAllChange(Sender: TObject);
begin
  for var idx := 0 to FAssets.Length - 1 do
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
    2: Value := FAssets[ARow].Name;
    3: Value := FAssets[ARow].Balance;
  end;
end;

procedure TfrmMain.GridSetValue(Sender: TObject; const ACol, ARow: Integer;
  const Value: TValue);
begin
  if ACol = 0 then FAssets[ARow].Check(Value.AsBoolean);
end;

//---------------------------------- private -----------------------------------

function TfrmMain.Cancelled: Boolean;
begin
  const P = progress.Get(Self);
  Result := Assigned(P) and P.Cancelled;
  if Result and P.Visible then
  begin
    P.Close;
    repeat
      TThread.Sleep(100);
    until not P.Visible;
  end;
end;

function TfrmMain.Chain: TChain;
begin
  const I = cboChain.ItemIndex;
  if (I > -1) and (I < cboChain.Count) then
  begin
    const chain = web3.Chain(UInt32(cboChain.Items.Objects[I]));
    if chain.IsOk then
    begin
      Result := chain.Value^;
      EXIT;
    end;
  end;
  Result := web3.Ethereum;
end;

procedure TfrmMain.Clear;
begin
  FAssets := [];
  Grid.RowCount := 0;
  chkSelectAll.Enabled := False;
  chkSelectAll.IsChecked := True;
  btnMigrate.Enabled := False;
  Self.Invalidate;
end;

function TfrmMain.GetClient: IResult<IWeb3>;
begin
  const endpoint = web3.eth.infura.endpoint(Chain, INFURA_PROJECT_ID);
  if endpoint.IsErr then
  begin
    Result := TResult<IWeb3>.Err(nil, endpoint.Error);
    EXIT;
  end;

  const client = TWeb3.Create(Chain.SetGateway(HTTPS, endpoint.Value));
  // do not approve each and every transaction individually
  client.OnSignatureRequest := procedure(
    from, &to   : TAddress;
    gasPrice    : TWei;
    estimatedGas: BigInteger;
    callback    : TSignatureRequestResult)
  begin
    callback(True, nil);
  end;

  Result := TResult<IWeb3>.Ok(client);
end;

procedure TfrmMain.Count(aSettings: TSettings; callback: TProc<BigInteger, IError>);
begin
  // step #1: count the tokens on this chain that Uniswap knows about
  web3.eth.tokenlists.count(Chain, procedure(cnt1: BigInteger; err: IError)
  begin
    ( // step #2: count the Uniswap v2 LP tokens (optional)
      procedure(return: TProc<BigInteger, IError>)
      begin
        if UniswapPairs in aSettings then
          web3.eth.tokenlists.count(UNISWAP_PAIR_TOKENS, return)
        else
          return(0, nil);
      end
    )(procedure(cnt2: BigInteger; err: IError)
      begin
        callback(cnt1 + cnt2, err);
      end);
  end);
end;

class function TfrmMain.Ethereum: IWeb3;
begin
  Result := TWeb3.Create(web3.Ethereum.SetGateway(HTTPS, web3.eth.infura.endpoint(web3.Ethereum, INFURA_PROJECT_ID).Value));
end;

procedure TfrmMain.Generate;
begin
  const &private = TPrivateKey.Generate;

  const &public = &private.GetAddress;
  if &public.IsErr then
  begin
    web3.error.show(Chain, &public.Error);
    EXIT;
  end;

  var svc: IFMXClipboardService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, svc) then
    svc.SetClipboard(string(&private));

  Self.Synchronize(procedure
  begin
    edtRecipient.Text := string(&public.Value);
    MessageDlg(
      'A new wallet has been generated for you.' + #10#10 +
      'Your private key has been copied to the clipboard.' + #10#10 +
      'Please paste your private key in a safe place (for example: your password manager), then clear the clipboard.',
      TMsgDlgType.mtInformation, [TMsgDlgBtn.mbOK], 0);
  end);
end;

procedure TfrmMain.Init;
const
  VERSION = {$I migratooor.version};
begin
  Self.Caption := Self.Caption + ' v' + VERSION;
  Grid.AutoHide := TBehaviorBoolean.False;
  cboChain.Items.BeginUpdate;
  try
    cboChain.Items.AddObject(web3.Ethereum.Name, TObject(web3.Ethereum.Id));
    cboChain.Items.AddObject(web3.Goerli.Name,   TObject(web3.Goerli.Id));
    cboChain.Items.AddObject(web3.BNB.Name,      TObject(web3.BNB.Id));
    cboChain.Items.AddObject(web3.Polygon.Name,  TObject(web3.Polygon.Id));
    cboChain.Items.AddObject(web3.Optimism.Name, TObject(web3.Optimism.Id));
    cboChain.Items.AddObject(web3.Arbitrum.Name, TObject(web3.Arbitrum.Id));
    cboChain.Items.AddObject(web3.Fantom.Name,   TObject(web3.Fantom.Id));
    cboChain.Items.AddObject(web3.Gnosis.Name,   TObject(web3.Gnosis.Id));
  finally
    cboChain.Items.EndUpdate;
  end;
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
  const checked = FAssets.Checked;
  if checked = 0 then
  begin
    web3.error.show('Nothing to do.');
    EXIT;
  end;
  Self.Owner(procedure(aOwner: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      web3.error.show(web3.Ethereum, err);
      EXIT;
    end;
    aOwner.ToString(Ethereum, procedure(sOwner: string; err: IError)
    begin
      if Assigned(err) then
      begin
        web3.error.show(web3.Ethereum, err);
        EXIT;
      end;
      Self.Recipient(procedure(aRecipient: TAddress; err: IError)
      begin
        if Assigned(err) then
        begin
          web3.error.show(web3.Ethereum, err);
          EXIT;
        end;
        aRecipient.ToString(Ethereum, procedure(sRecipient: string; err: IError)
        begin
          if Assigned(err) then
          begin
            web3.error.show(web3.Ethereum, err);
            EXIT;
          end;
          var answer: Integer;
          Self.Synchronize(procedure
          begin
            answer := MessageDlg(
              Format('Are you sure you want to migrate %d tokens from %s to %s on the %s network?', [checked, sOwner, sRecipient, Chain.Name]),
              TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0
            )
          end);
          if answer = mrYes then
          begin
            const client = Self.GetClient;
            if client.IsErr then
            begin
              web3.error.show(Chain, client.Error);
              EXIT;
            end;

            const &private = TPrivateKey.Prompt(aOwner);
            if &private.IsErr then
            begin
              if Supports(&private.Error, ICancelled) then
                { nothing }
              else
                web3.error.show(Chain, &private.Error);
              EXIT;
            end;

            FAssets.Enumerate(
              // foreach
              procedure(idx: Integer; next: TProc)
              begin
                if not FAssets[idx].Checked then
                begin
                  next;
                  EXIT;
                end;

                Self.Queue(procedure
                begin
                  progress.Get(Self).Step('Sending transaction %d of %d. Please wait...', idx, checked);
                end);

                FAssets[idx].Transfer(client.Value, &private.Value, aRecipient, procedure(hash: TTxHash; err: IError)
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
            Self.Synchronize(procedure
            begin
              progress.Get(Self).Prompt(Format('Sending %d transactions. Please wait...', [checked]));
            end);
          end;
        end, True);
      end);
    end, True);
  end);
end;

procedure TfrmMain.Owner(callback: TProc<TAddress, IError>);
begin
  if edtOwner.Text.Length = 0 then
    callback(EMPTY_ADDRESS, nil)
  else
    TAddress.Create(Ethereum, edtOwner.Text, callback);
end;

procedure TfrmMain.Recipient(callback: TProc<TAddress, IError>);
begin
  TAddress.Create(Ethereum, edtRecipient.Text, procedure(recipient: TAddress; err: IError)
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

procedure TfrmMain.Scan(aSettings: TSettings);
begin
  Self.Clear;

  // step #1: resolve the owner ENS name
  Self.Owner(procedure(owner: TAddress; err: IError)
  begin
    if Self.Cancelled then EXIT;

    if Assigned(err) then
    begin
      web3.error.show(Chain, err);
      EXIT;
    end;

    // step #2: count the total number of tokens we can scan
    Self.Count(aSettings, procedure(cnt: BigInteger; err: IError)
    begin
      if Self.Cancelled then EXIT;

      if Assigned(err) then
      begin
        web3.error.show(Chain, err);
        EXIT;
      end;

      // step #3: get the tokens on this chain that Uniswap knows about
      web3.eth.tokenlists.tokens(Chain, procedure(tokens: TTokens; err: IError)
      begin
        if Self.Cancelled then EXIT;

        if Assigned(err) then
        begin
          web3.error.show(Chain, err);
          EXIT;
        end;

        const client = Self.GetClient;
        if client.IsErr then
        begin
          web3.error.show(Chain, client.Error);
          EXIT;
        end;

        var num := 0;

        tokens.Enumerate(
          // foreach
          procedure(idx: Integer; next: TProc)
          begin
            Inc(num, 1);

            Self.Queue(procedure
            begin
              progress.Get(Self).Step('Scanning for %d/%d tokens in your wallet. Please wait...', num, cnt.AsInteger);
            end);

            tokens[idx].Balance(client.Value, owner, procedure(balance: BigInteger; err: IError)
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
                Self.Queue(procedure
                begin
                  Grid.RowCount := FAssets.Length;
                  Self.Update;
                end);
              end;

              next;
            end);
          end,
          // done
          procedure
          begin
          ( // step #4: scan for (erc-721 and erc-1155) NFTs (optional)
            procedure(callback: TProc)
            begin
              if NFTs in aSettings then
              begin
                web3.eth.opensea.NFTs(Chain, OPENSEA_API_KEY, owner, procedure(tokens: TNFTs; err: IError)
                begin
                  if Self.Cancelled then EXIT;

                  if Assigned(err) then
                  begin
                    web3.error.show(Chain, err);
                    EXIT;
                  end;

                  tokens.Enumerate(
                    // foreach
                    procedure(idx: Integer; next: TProc)
                    begin
                      FAssets := FAssets + [asset.Create(tokens[idx])];
                      Self.Queue(procedure
                      begin
                        Grid.RowCount := FAssets.Length;
                        Self.Update;
                      end);
                      next;
                    end,
                    // done
                    callback
                  );
                end);
                EXIT;
              end;
              callback;
            end
          )(procedure
            begin
            ( // step #5: scan for 30k Uniswap v2 LP tokens (optional)
              procedure(callback: TProc)
              begin
                if UniswapPairs in aSettings then
                begin
                  web3.eth.tokenlists.tokens(UNISWAP_PAIR_TOKENS, procedure(tokens: TTokens; err: IError)
                  begin
                    if Self.Cancelled then EXIT;

                    if Assigned(err) then
                    begin
                      web3.error.show(Chain, err);
                      EXIT;
                    end;

                    tokens.Enumerate(
                      // foreach
                      procedure(idx: Integer; next: TProc)
                      begin
                        Inc(num, 1);

                        Self.Queue(procedure
                        begin
                          progress.Get(Self).Step('Scanning for %d/%d tokens in your wallet. Please wait...', num, cnt.AsInteger);
                        end);

                        tokens[idx].Balance(client.Value, owner, procedure(balance: BigInteger; err: IError)
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
                            Self.Queue(procedure
                            begin
                              Grid.RowCount := FAssets.Length;
                              Self.Update;
                            end);
                          end;

                          next;
                        end);
                      end,
                      // done
                      callback
                    );
                  end);
                  EXIT;
                end;
                callback;
              end
            )(procedure
              begin
                // step #6: download and display the token icon
                FAssets.Enumerate(
                  // foreach
                  procedure(idx: Integer; next: TProc)
                  begin
                    if FAssets[idx].Logo.IsEmpty then
                    begin
                      next;
                      EXIT;
                    end;

                    web3.http.get(FAssets[idx].Logo, [], procedure(img: IHttpResponse; err: IError)
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

                      Queue(procedure
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
            end
          );
          end
        );
      end);
    end);
  end);

  progress.Get(Self).Prompt('Scanning for tokens in your wallet. Please wait...');
end;

function TfrmMain.Settings: TSettings;
begin
  Result := [];
  if (Chain = web3.Ethereum) and chkScanForUniswapPairs.IsChecked then
    Result := Result + [UniswapPairs];
  if ((Chain = web3.Ethereum) or (Chain = web3.Goerli)) and chkScanForNFTs.IsChecked then
    Result := Result + [NFTs];
end;

class procedure TfrmMain.Queue(P: TThreadProcedure);
begin
  if TThread.CurrentThread.ThreadID = MainThreadId then
    P
  else
    TThread.Queue(nil, procedure
    begin
      P
    end);
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

procedure TfrmMain.Update;
begin
  chkSelectAll.Enabled := Self.FAssets.Length > 0;
  btnMigrate.Enabled := Self.FAssets.Length > 0;
  Self.Invalidate;
end;

//---------------------------------- public -----------------------------------

constructor TfrmMain.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  Init;
end;

end.
