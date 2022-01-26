unit common;

interface

uses
  // web3
  web3;

const
  CHAINS: array[0..9] of TChain = (
    Ethereum,
    Ropsten,
    Rinkeby,
    Kovan,
    Goerli,
    BSC,
    Polygon,
    Optimism,
    Arbitrum,
    Gnosis);

const
  INFURA_PROJECT_ID = '9aa3d95b3bc440fa88ea12eaa4456161';
  IPFS_GATEWAY      = 'https://ipfs.io/ipfs/';

procedure ShowError(const msg: string); overload;
procedure ShowError(const err: IError; chain: TChain); overload;

procedure OpenURL(const URL: string);
procedure OpenTransaction(chain: TChain; tx: TTxHash);

function GetPrivateKey(&public: TAddress): TPrivateKey;

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

function GetPrivateKey(&public: TAddress): TPrivateKey;
resourcestring
  RS_PRIVATE_KEY_IS_INVALID = 'Private key is invalid';
begin
  Result := '';

  var &private: TPrivateKey;
  TThread.Synchronize(nil, procedure
  begin
    &private := TPrivateKey(Trim(InputBox(string(&public), 'Please paste your private key', '')));
  end);

  if &private = '' then
    EXIT;
  if (
    (not web3.utils.isHex('', string(&private)))
  or
    (Length(&private) <> SizeOf(TPrivateKey) - 1)) then
  begin
    common.ShowError(RS_PRIVATE_KEY_IS_INVALID);
    EXIT;
  end;

  &private.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      common.ShowError(err.Message);
      &private := '';
    end;
    if string(addr).ToUpper <> string(&public).ToUpper then
    begin
      common.ShowError(RS_PRIVATE_KEY_IS_INVALID);
      &private := '';
    end;
  end);

  Result := &private;
end;

end.
