unit common;

interface

uses
  // web3
  web3;

function GetPrivateKey(&public: TAddress): IResult<TPrivateKey>;

implementation

uses
  // Delphi
  System.Classes,
  System.SysUtils,
  System.UITypes,
  // FireMonkey
  FMX.Dialogs,
  // web3
  web3.error,
  web3.eth.tx,
  web3.eth.types,
  web3.utils;

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
