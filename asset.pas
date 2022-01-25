unit asset;

interface

uses
  // FireMonkey
  FMX.Graphics,
  // web3
  web3.eth.tokenlists;

type
  IAsset = interface
    function Token: IToken;
    function Bitmap: TBitmap;
    function Checked: Boolean;
    function Check(Value: Boolean): IAsset;
  end;

function Create(const aToken: IToken): IAsset;

implementation

type
  TAsset = class(TInterfacedObject, IAsset)
  private
    FToken: IToken;
    FBitmap: TBitmap;
    FChecked: Boolean;
  public
    function Token: IToken;
    function Bitmap: TBitmap;
    function Checked: Boolean;
    function Check(Value: Boolean): IAsset;
    constructor Create(const aToken: IToken);
    destructor Destroy; override;
  end;

constructor TAsset.Create(const aToken: IToken);
begin
  inherited Create;
  FToken := aToken;
  FChecked := True;
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

function Create(const aToken: IToken): IAsset;
begin
  Result := TAsset.Create(aToken);
end;

end.
