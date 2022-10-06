unit common;

interface

uses
  // web3
  web3;

const
  CHAINS: array[0..10] of TChain = (
    Ethereum,
    Ropsten,
    Rinkeby,
    Kovan,
    Goerli,
    BNB,
    Polygon,
    Optimism,
    Arbitrum,
    Fantom,
    Gnosis);

type
  ICancelled = interface(IError)
  ['{EB6305B0-A310-43ED-A868-8BCB3334B11F}']
  end;
  TCancelled = class(TError, ICancelled)
  public
    constructor Create;
  end;

procedure ShowError(const msg: string); overload;
procedure ShowError(const err: IError; chain: TChain); overload;

procedure OpenURL(const URL: string);
procedure OpenTransaction(chain: TChain; tx: TTxHash);

function GetPrivateKey(&public: TAddress): IResult<TPrivateKey>;

implementation

uses
  // Delphi
  System.Classes,
  System.SysUtils,
  System.UITypes,
{$IFDEF MSWINDOWS}
  WinAPI.ShellAPI,
  WinAPI.Windows,
{$ENDIF MSWINDOWS}
{$IFDEF POSIX}
  Posix.Stdlib,
{$ENDIF POSIX}
  // FireMonkey
  FMX.Dialogs,
  // web3
  web3.eth.tx,
  web3.eth.types,
  web3.utils;

constructor TCancelled.Create;
begin
  inherited Create('');
end;

procedure ShowError(const msg: string);
begin
  TThread.Synchronize(nil, procedure
  begin
    MessageDlg(msg, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);
  end);
end;

procedure ShowError(const err: IError; chain: TChain);
begin
  if Supports(err, ISignatureDenied) then
    EXIT;
  TThread.Synchronize(nil, procedure
  var
    txError: ITxError;
  begin
    if Supports(err, ITxError, txError) then
    begin
      if MessageDlg(
        Format(
          '%s. Would you like to view this transaction on etherscan?',
          [err.Message]
        ),
        TMsgDlgType.mtError, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0
      ) = mrYes then
        OpenTransaction(chain, txError.Hash);
      EXIT;
    end;
    MessageDlg(err.Message, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);
  end);
end;

procedure OpenURL(const URL: string);
begin
{$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL);
{$ENDIF MSWINDOWS}
{$IFDEF POSIX}
  _system(PAnsiChar('open ' + AnsiString(URL)));
{$ENDIF POSIX}
end;

procedure OpenTransaction(chain: TChain; tx: TTxHash);
begin
  OpenURL(chain.BlockExplorerURL + '/tx/' + string(tx));
end;

function GetPrivateKey(&public: TAddress): IResult<TPrivateKey>;
begin
  var &private: TPrivateKey;
  TThread.Synchronize(nil, procedure
  begin
    &private := TPrivateKey(Trim(InputBox(string(&public), 'Please paste your private key', '')));
  end);

  if &private = '' then
  begin
    Result := TResult<TPrivateKey>.Err('', TCancelled.Create);
    EXIT;
  end;

  if (
    (not web3.utils.isHex('', string(&private)))
  or
    (Length(&private) <> SizeOf(TPrivateKey) - 1)) then
  begin
    Result := TResult<TPrivateKey>.Err('', 'Private key is invalid');
    EXIT;
  end;

  const address = &private.GetAddress;
  if address.IsErr then
  begin
    Result := TResult<TPrivateKey>.Err('', address.Error);
    EXIT;
  end;
  if address.Value.ToChecksum <> &public.ToChecksum then
  begin
    Result := TResult<TPrivateKey>.Err('', 'Private key is invalid');
    EXIT;
  end;

  Result := TResult<TPrivateKey>.Ok(&private);
end;

end.
