unit asset;

interface

uses
  // Delphi
  System.SysUtils,
  // FireMonkey
  FMX.Graphics,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.tokenlists,
  web3.eth.types;

type
  IAsset = interface
    function Token: IToken;
    function Balance: Double;
    function Bitmap: TBitmap;
    function Checked: Boolean;
    function Check(Value: Boolean): IAsset;
    procedure Transfer(client: IWeb3; from: TPrivateKey; &to: TAddress; callback: TAsyncTxHash);
  end;

  TAssets = TArray<IAsset>;

  TAssetsHelper = record helper for TAssets
    function Checked: Integer;
    procedure Enumerate(foreach: TProc<Integer, TProc>; done: TProc);
  end;

function Create(const aToken: IToken; aBalance: BigInteger): IAsset;

implementation

uses
  // Delphi
  System.Math,
  // web3
  web3.eth.erc20;

{----------------------------------- TAsset -----------------------------------}

type
  TAsset = class(TInterfacedObject, IAsset)
  private
    FToken: IToken;
    FBitmap: TBitmap;
    FChecked: Boolean;
    FBalance: BigInteger;
  public
    function Token: IToken;
    function Balance: Double;
    function Bitmap: TBitmap;
    function Checked: Boolean;
    function Check(Value: Boolean): IAsset;
    procedure Transfer(client: IWeb3; from: TPrivateKey; &to: TAddress; callback: TAsyncTxHash);
    constructor Create(const aToken: IToken; aBalance: BigInteger);
    destructor Destroy; override;
  end;

constructor TAsset.Create(const aToken: IToken; aBalance: BigInteger);
begin
  inherited Create;
  FToken := aToken;
  FChecked := True;
  FBalance := aBalance;
end;

destructor TAsset.Destroy;
begin
  if Assigned(FBitmap) then FBitmap.Free;
  inherited Destroy;
end;

function TAsset.Token: IToken;
begin
  Result := FToken;
end;

function TAsset.Balance: Double;
begin
  if Self.Token.Decimals = 0 then
    Result := FBalance.AsDouble
  else
    Result := FBalance.AsDouble / Power(10, Self.Token.Decimals);
end;

function TAsset.Bitmap: TBitmap;
begin
  if not Assigned(FBitmap) then
    FBitmap := TBitmap.Create;
  Result := FBitmap;
end;

function TAsset.Checked: Boolean;
begin
  Result := FChecked;
end;

function TAsset.Check(Value: Boolean): IAsset;
begin
  FChecked := Value;
  Result := Self;
end;

procedure TAsset.Transfer(client: IWeb3; from: TPrivateKey; &to: TAddress; callback: TAsyncTxHash);
begin
  var erc20 := TERC20.Create(client, Self.Token.Address);
  try
    erc20.Transfer(from, &to, FBalance, callback);
  finally
    erc20.Free;
  end;
end;

{---------------------------------- TAssets -----------------------------------}

function TAssetsHelper.Checked: Integer;
begin
  Result := 0;
  for var asset in Self do
    if asset.Checked then Inc(Result);
end;

procedure TAssetsHelper.Enumerate(foreach: TProc<Integer, TProc>; done: TProc);
begin
  var next: TProc<TAssets, Integer>;

  next := procedure(assets: TAssets; idx: Integer)
  begin
    if idx >= Length(assets) then
    begin
      if Assigned(done) then done;
      EXIT;
    end;
    foreach(idx, procedure
    begin
      next(assets, idx + 1);
    end);
  end;

  if Length(Self) = 0 then
  begin
    if Assigned(done) then done;
    EXIT;
  end;

  next(Self, 0);
end;

{----------------------------------- public -----------------------------------}

function Create(const aToken: IToken; aBalance: BigInteger): IAsset;
begin
  Result := TAsset.Create(aToken, aBalance);
end;

end.
