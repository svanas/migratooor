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
  web3.eth.opensea,
  web3.eth.tokenlists,
  web3.eth.types;

type
  IAsset = interface
    function Balance: Double;
    function Bitmap: TBitmap;
    function Checked: Boolean;
    function Check(Value: Boolean): IAsset;
    function Logo: TURL;
    function Name: string;
    procedure Transfer(client: IWeb3; from: TPrivateKey; &to: TAddress; callback: TProc<TTxHash, IError>);
  end;

  TAssets = TArray<IAsset>;

  TAssetsHelper = record helper for TAssets
    function Checked: Integer;
    procedure Enumerate(foreach: TProc<Integer, TProc>; done: TProc);
    function Length: Integer;
  end;

function Create(const aToken: IToken; aBalance: BigInteger): IAsset; overload;
function Create(const aNFT: INFT): IAsset; overload;

implementation

uses
  // Delphi
  System.Math,
  // web3
  web3.eth.erc20,
  web3.eth.erc721,
  web3.eth.erc1155,
  web3.eth.tx;

{----------------------------------- TAsset -----------------------------------}

type
  TAsset = class(TInterfacedObject, IAsset)
  private
    FAddress : TAddress;
    FBalance : BigInteger;
    FBitmap  : TBitmap;
    FChecked : Boolean;
    FDecimals: Integer;
    FLogo    : TURL;
    FName    : string;
    FType    : TAssetType;
    FFTokenId: BigInteger;
  public
    function Balance: Double;
    function Bitmap: TBitmap;
    function Checked: Boolean;
    function Check(Value: Boolean): IAsset;
    function Logo: TURL;
    function Name: string;
    procedure Transfer(client: IWeb3; from: TPrivateKey; &to: TAddress; callback: TProc<TTxHash, IError>);
    constructor Create(
      aType      : TAssetType;
      aAddress   : TAddress;
      aTokenId   : BigInteger;
      const aName: string;
      aDecimals  : Integer;
      const aLogo: TURL;
      aBalance   : BigInteger);
    destructor Destroy; override;
  end;

constructor TAsset.Create(
  aType      : TAssetType;
  aAddress   : TAddress;
  aTokenId   : BigInteger;
  const aName: string;
  aDecimals  : Integer;
  const aLogo: TURL;
  aBalance   : BigInteger);
begin
  inherited Create;
  FAddress  := aAddress;
  FBalance  := aBalance;
  FChecked  := True;
  FDecimals := aDecimals;
  FLogo     := aLogo;
  FName     := aName;
  FType     := aType;
  FFTokenId := aTokenId;
end;

destructor TAsset.Destroy;
begin
  if Assigned(FBitmap) then FBitmap.Free;
  inherited Destroy;
end;

function TAsset.Balance: Double;
begin
  if FDecimals = 0 then
    Result := FBalance.AsDouble
  else
    Result := FBalance.AsDouble / Power(10, FDecimals);
end;

function TAsset.Bitmap: TBitmap;
begin
  if not Assigned(FBitmap) then FBitmap := TBitmap.Create;
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

function TAsset.Logo: TURL;
begin
  Result := FLogo.Replace('ipfs://', 'https://ipfs.io/ipfs/');
end;

function TAsset.Name: string;
begin
  Result := FName;
end;

procedure TAsset.Transfer(client: IWeb3; from: TPrivateKey; &to: TAddress; callback: TProc<TTxHash, IError>);
begin
  case FType of
    native:
      web3.eth.tx.sendTransaction(client, from, &to, FBalance, callback);
    erc20:
    begin
      const erc20 = TERC20.Create(client, FAddress);
      try
        erc20.Transfer(from, &to, FBalance, callback);
      finally
        erc20.Free;
      end;
    end;
    erc721:
    begin
      const erc721 = TERC721.Create(client, FAddress);
      try
        erc721.SafeTransferFrom(from, &to, FFTokenId, callback);
      finally
        erc721.Free;
      end;
    end;
    erc1155:
    begin
      const erc1155 = TERC1155.Create(client, FAddress);
      try
        erc1155.SafeTransferFrom(from, &to, FFTokenId, FBalance, callback);
      finally
        erc1155.Free;
      end;
    end;
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
    if idx >= assets.Length then
    begin
      if Assigned(done) then done;
      EXIT;
    end;
    foreach(idx, procedure
    begin
      next(assets, idx + 1);
    end);
  end;

  if Self.Length = 0 then
  begin
    if Assigned(done) then done;
    EXIT;
  end;

  next(Self, 0);
end;

function TAssetsHelper.Length: Integer;
begin
  Result := System.Length(Self);
end;

{----------------------------------- public -----------------------------------}

function Create(const aToken: IToken; aBalance: BigInteger): IAsset;
begin
  Result := TAsset.Create(erc20, aToken.Address, 0, aToken.Name, aToken.Decimals, aToken.Logo, aBalance);
end;

function Create(const aNFT: INFT): IAsset;
begin
  Result := TAsset.Create(aNFT.Asset, aNFT.Address, aNFT.TokenId, aNFT.Name, 0, aNFT.Image, 1);
end;

end.
